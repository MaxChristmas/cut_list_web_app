#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Offcut reuse feasibility analysis — CutOptima
# Read-only: writes only to tmp/offcut_analysis.csv
# Run: bin/rails runner script/offcut_analysis.rb
#
# HYPOTHESES (reproduced in the final summary):
#   H1  material_key = "stock_width×stock_length" from result["stock"]
#       (no material type / thickness column exists in the schema)
#   H2  Strip-cut offcut model: two non-overlapping strips per sheet
#         end_strip  = (stock_l - max_x_extent) × stock_w
#         side_strip = max_x_extent × (stock_w - max_y_extent)
#       where max_x/y_extent = furthest occupied coordinate per axis
#   H3  A strip is "exploitable" only if both its dims ≥ MIN_OFFCUT_DIM_MM
#   H4  One optimization per project: the most recent completed one
#   H5  Offcut pool is per (user × material_key), consumed greedily (first fit)
#   H6  Piece fitting allows 90° rotation
#   H7  Internal users and NULL-user projects are excluded
#   H8  Discarded / soft-deleted users are excluded

require "digest"
require "csv"

# ── Tuneable constants ────────────────────────────────────────────────────────
MIN_OFFCUT_DIM_MM   = 200   # min size (both axes) for an offcut to be exploitable
RECURRING_THRESHOLD = 3     # min projects to be considered a "recurring user"

# ── Helpers ───────────────────────────────────────────────────────────────────

def user_hash(id)
  Digest::SHA256.hexdigest("salt_cutoptima_offcut_#{id}")[0, 12]
end

# Estimate exploitable rectangular offcuts from one sheet's placements.
# Returns array of [short_dim, long_dim] pairs (both in mm, sorted min first).
# See H2 for the strip-cut model.
def offcut_strips(placements, stock_w, stock_l)
  return [] if placements.empty?

  # x axis = along length, y axis = along width  (confirmed from JSONB inspection)
  max_x = placements.map { |p| p["x"].to_i + p["rect"]["length"].to_i }.max
  max_y = placements.map { |p| p["y"].to_i + p["rect"]["width"].to_i }.max

  strips = []

  end_l = stock_l - max_x
  if end_l >= MIN_OFFCUT_DIM_MM && stock_w >= MIN_OFFCUT_DIM_MM
    strips << [stock_w, end_l].minmax.to_a
  end

  side_w = stock_w - max_y
  if max_x >= MIN_OFFCUT_DIM_MM && side_w >= MIN_OFFCUT_DIM_MM
    strips << [max_x, side_w].minmax.to_a
  end

  strips
end

# Does piece (pw × pl) fit inside offcut (odim1 × odim2), rotation allowed?
def fits?(pw, pl, odim1, odim2)
  pw_s, pw_l = [pw, pl].minmax
  ow_s, ow_l = [odim1, odim2].minmax
  pw_s <= ow_s && pw_l <= ow_l
end

# ── Data loading ──────────────────────────────────────────────────────────────
puts "Loading data..."

real_user_ids = User.where(internal: false, discarded_at: nil).pluck(:id)

# Latest completed optimization per project (PostgreSQL DISTINCT ON)
latest_opt_scope = Optimization
  .select("DISTINCT ON (project_id) id")
  .where(status: "completed")
  .where.not(result: nil)
  .order("project_id, created_at DESC")

opts_by_project = Optimization
  .where(id: latest_opt_scope)
  .index_by(&:project_id)

puts "  Completed optimizations indexed: #{opts_by_project.size}"

projects_by_user = Hash.new { |h, k| h[k] = [] }
skipped = 0

Project
  .where(user_id: real_user_ids, template: false)
  .order(:user_id, :created_at)
  .select(:id, :user_id, :created_at, :sheet_width, :sheet_length)
  .each do |proj|
    opt = opts_by_project[proj.id]
    unless opt
      skipped += 1
      next
    end

    res   = opt.result
    stock = res["stock"]
    unless stock&.key?("width") && stock&.key?("length")
      skipped += 1
      next
    end

    sw = stock["width"].to_i
    sl = stock["length"].to_i
    if sw.zero? || sl.zero?
      skipped += 1
      next
    end

    projects_by_user[proj.user_id] << {
      project_id:   proj.id,
      created_at:   proj.created_at,
      material_key: "#{sw}x#{sl}",
      stock_w:      sw,
      stock_l:      sl,
      pieces:       res["pieces"] || [],
      sheets:       res["sheets"] || [],
      sheet_count:  (res["sheet_count"] || 1).to_i,
      waste_percent: res["waste_percent"].to_f
    }
  end

total_users = projects_by_user.size
puts "  #{skipped} projects skipped (no valid completed optimization)"
puts "  #{projects_by_user.values.sum(&:size)} valid projects across #{total_users} users"

# ─── METRIC 1: Recurrence ────────────────────────────────────────────────────
puts "\n=== METRIC 1: Recurrence ==="

recurring_users    = projects_by_user.count { |_, ps| ps.size >= RECURRING_THRESHOLD }
recurring_pct      = total_users > 0 ? (100.0 * recurring_users / total_users).round(1) : 0.0

puts "Users with ≥1 valid project: #{total_users}"
puts "Users with ≥#{RECURRING_THRESHOLD} projects (recurring): #{recurring_users} (#{recurring_pct}%)"
puts "\nDistribution:"
(1..10).each do |n|
  c = n < 10 ? projects_by_user.count { |_, ps| ps.size == n } : projects_by_user.count { |_, ps| ps.size >= 10 }
  label = n < 10 ? "= #{n}" : "≥10"
  puts "  #{label} project(s): #{c} users"
end

# Inter-project gaps
gaps_days = []
projects_by_user.each do |_, ps|
  next if ps.size < 2
  ps.sort_by { |p| p[:created_at] }.each_cons(2) do |a, b|
    gaps_days << (b[:created_at] - a[:created_at]) / 86_400.0
  end
end

gap_stats = nil
if gaps_days.any?
  sg = gaps_days.sort
  n  = sg.size
  gap_stats = {
    n:      n,
    p25:    sg[(n * 0.25).to_i].round(0).to_i,
    median: sg[n / 2].round(0).to_i,
    p75:    sg[(n * 0.75).to_i].round(0).to_i
  }
  puts "\nInter-project gap (days, n=#{gap_stats[:n]}): " \
       "P25=#{gap_stats[:p25]}, median=#{gap_stats[:median]}, P75=#{gap_stats[:p75]}"
end

# Material key concentration on recurring users
recurring_mat = projects_by_user
  .select { |_, ps| ps.size >= RECURRING_THRESHOLD }
  .map do |_, ps|
    distinct = ps.map { |p| p[:material_key] }.uniq.size
    { n_proj: ps.size, n_mat: distinct, ratio: distinct.to_f / ps.size }
  end

if recurring_mat.any?
  avg_ratio    = (recurring_mat.sum { |r| r[:ratio] } / recurring_mat.size).round(2)
  single_mat_n = recurring_mat.count { |r| r[:n_mat] == 1 }
  single_mat_p = (100.0 * single_mat_n / recurring_mat.size).round(1)
  puts "\nMaterial concentration — recurring users (n=#{recurring_mat.size}):"
  puts "  Avg (distinct formats / nb projects): #{avg_ratio}  [1.0=all different, ~0=concentrated]"
  puts "  Users with a single panel format across all projects: #{single_mat_n} (#{single_mat_p}%)"
end

# Piece dimension distribution
small_dims = []
projects_by_user.each_value do |ps|
  ps.each do |proj|
    proj[:pieces].each do |p|
      w   = p["width"].to_i
      l   = p["length"].to_i
      qty = p["quantity"].to_i.clamp(1, 200)
      next if w.zero? || l.zero?
      qty.times { small_dims << [w, l].min }
    end
  end
end

if small_dims.any?
  sd = small_dims.sort
  n  = sd.size
  pct_over_min = (100.0 * small_dims.count { |d| d >= MIN_OFFCUT_DIM_MM } / n).round(1)
  puts "\nPiece min-dimension (mm), n=#{n}:"
  puts "  P10=#{sd[(n*0.10).to_i]}  P25=#{sd[(n*0.25).to_i]}  " \
       "median=#{sd[n/2]}  P75=#{sd[(n*0.75).to_i]}  P90=#{sd[(n*0.90).to_i]}"
  puts "  Pieces with both dims ≥ #{MIN_OFFCUT_DIM_MM}mm: #{pct_over_min}%"
end

# ─── METRIC 2: Offcut reuse simulation ───────────────────────────────────────
puts "\n=== METRIC 2: Offcut reuse simulation ==="
puts "  (H1-H8 as described at the top of the file)"

total_oc_all = 0; reused_oc_all = 0
total_oc_rec = 0; reused_oc_rec = 0

csv_rows = []

projects_by_user.each do |user_id, ps|
  sorted      = ps.sort_by { |p| p[:created_at] }
  is_recurring = sorted.size >= RECURRING_THRESHOLD

  # offcut pool: material_key => [{dims: [short, long], consumed: bool}]
  pool = Hash.new { |h, k| h[k] = [] }

  sorted.each do |proj|
    mat = proj[:material_key]
    sw  = proj[:stock_w]
    sl  = proj[:stock_l]

    # Step 1: try to consume existing offcuts with this project's pieces
    available = pool[mat].reject { |o| o[:consumed] }

    proj[:pieces].each do |piece|
      pw  = piece["width"].to_i
      pl  = piece["length"].to_i
      qty = piece["quantity"].to_i.clamp(1, 200)
      next if pw.zero? || pl.zero?

      qty.times do
        break if available.empty?
        oc = available.find { |o| fits?(pw, pl, o[:dims][0], o[:dims][1]) }
        next unless oc

        oc[:consumed] = true
        available.delete(oc)
        reused_oc_all += 1
        reused_oc_rec += 1 if is_recurring
      end
    end

    # Step 2: generate offcuts from this project's sheets into the pool
    proj_oc_dims = []
    proj[:sheets].each do |sheet|
      offcut_strips(sheet["placements"] || [], sw, sl).each do |dims|
        entry = { dims: dims, consumed: false }
        pool[mat] << entry
        proj_oc_dims << dims
        total_oc_all += 1
        total_oc_rec += 1 if is_recurring
      end
    end

    # CSV row
    nb_pieces    = proj[:pieces].sum { |p| p["quantity"].to_i.clamp(1, 200) }
    surf_pieces  = proj[:pieces].sum { |p| p["width"].to_i * p["length"].to_i * p["quantity"].to_i.clamp(1, 200) }
    surf_panneau = sw * sl * proj[:sheet_count]
    dims_p = proj[:pieces].map { |p| "#{p["width"]}x#{p["length"]}(x#{p["quantity"]})" }.join("|")
    dims_o = proj_oc_dims.map { |d| "#{d[0]}x#{d[1]}" }.join("|")

    csv_rows << [
      user_hash(user_id),
      proj[:created_at].strftime("%Y-%m-%d"),
      mat,
      nb_pieces,
      dims_p,
      dims_o,
      surf_pieces,
      surf_panneau
    ]
  end
end

rate_all = total_oc_all > 0 ? (100.0 * reused_oc_all / total_oc_all).round(1) : 0.0
rate_rec = total_oc_rec > 0 ? (100.0 * reused_oc_rec / total_oc_rec).round(1) : 0.0

puts "Offcuts generated:"
puts "  All users:        #{total_oc_all}"
puts "  Recurring users:  #{total_oc_rec}"
puts "Offcuts reusable (simulation):"
puts "  All users:        #{reused_oc_all} / #{total_oc_all} = #{rate_all}%"
puts "  Recurring users:  #{reused_oc_rec} / #{total_oc_rec} = #{rate_rec}%"

# ─── CSV export ───────────────────────────────────────────────────────────────
csv_path = Rails.root.join("tmp/offcut_analysis.csv")
CSV.open(csv_path, "w") do |csv|
  csv << %w[user_hash created_at material_key nb_pieces
            dimensions_pieces dimensions_offcuts
            surface_pieces_mm2 surface_panneaux_mm2]
  csv_rows.each { |row| csv << row }
end
puts "\nCSV: #{csv_path} (#{csv_rows.size} rows)"

# ─── Markdown summary ─────────────────────────────────────────────────────────
gap_str  = gap_stats ? "#{gap_stats[:median]} j (P25=#{gap_stats[:p25]}, P75=#{gap_stats[:p75]})" : "N/A"
mat_str  = recurring_mat.any? ? "#{avg_ratio} (#{single_mat_p}% avec format unique)" : "N/A"

threshold_rec  = recurring_pct >= 20 ? "OUI (#{recurring_pct}%)"  : "NON (#{recurring_pct}%)"
threshold_rate = rate_all       >= 15 ? "OUI (#{rate_all}%)"       : "NON (#{rate_all}%)"
threshold_rrec = rate_rec       >= 20 ? "OUI (#{rate_rec}%)"       : "NON (#{rate_rec}%)"

puts "\n" + "=" * 72
puts <<~MARKDOWN

  ## Analyse offcuts — verdict (#{Date.today})

  ### Hypothèses retenues
  - `material_key` = format de panneau uniquement (`stock_w×stock_l`). Aucune
    colonne matière/épaisseur n'existe dans le schéma, ce qui sous-estime
    la concentration réelle (deux projets avec le même format mais des matières
    différentes sont incorrectement groupés).
  - Modèle de chute : deux bandes rectangulaires par feuille (bande de fond +
    bande latérale), exploitables si les deux dimensions ≥ #{MIN_OFFCUT_DIM_MM} mm.
  - Consommation des chutes : greedy first-fit, rotation 90° autorisée.
  - Une seule optimisation par projet retenue : la plus récente complétée.

  ### 1. Récurrence
  | Métrique | Valeur |
  |----------|--------|
  | Users avec ≥1 projet optimisé | #{total_users} |
  | Users récurrents (≥#{RECURRING_THRESHOLD} projets) | #{recurring_users} (#{recurring_pct}%) |
  | Gap médian entre projets consécutifs | #{gap_str} |

  ### 2. Concentration matière (users récurrents, n=#{recurring_mat.size})
  | Métrique | Valeur |
  |----------|--------|
  | Ratio distinct_formats/projets (moy.) | #{mat_str} |

  ### 3. Simulation réutilisation
  | Segment | Offcuts générés | Réutilisables | Taux |
  |---------|-----------------|---------------|------|
  | Tous users | #{total_oc_all} | #{reused_oc_all} | #{rate_all}% |
  | Users récurrents (≥#{RECURRING_THRESHOLD} projets) | #{total_oc_rec} | #{reused_oc_rec} | #{rate_rec}% |

  ### Seuils de viabilité de la feature
  | Seuil | Résultat |
  |-------|----------|
  | Récurrence ≥ 20% des users | #{threshold_rec} |
  | Taux de réutilisation global ≥ 15% | #{threshold_rate} |
  | Taux de réutilisation users récurrents ≥ 20% | #{threshold_rrec} |

  ### Avis
  La feature offcuts vaut le développement si les 3 seuils sont atteints.
  Sans colonne `material_type` / `thickness` dans la base, le matching ne peut
  se faire que par format de panneau — une feature utile nécessiterait d'abord
  d'ajouter ce champ au modèle `Project`, sinon les suggestions seront bruitées.

MARKDOWN
