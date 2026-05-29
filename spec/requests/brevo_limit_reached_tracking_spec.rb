require "rails_helper"

RSpec.describe "Brevo limit_reached tracking", type: :request do
  REQUIRED_LIMIT_REACHED_PROPERTIES = %i[
    subject heading message cta_text cta_url footer
    limit_type one_shot_price one_shot_duration tagline copyright
  ].freeze

  let(:user) do
    User.create!(
      email: "brevo-tracking-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      plan: "free"
    )
  end

  let(:project) do
    user.projects.create!(name: "Test Project", sheet_length: 2440, sheet_width: 1220)
  end

  let(:valid_params) do
    { stock_l: 2440, stock_w: 1220, pieces: [ { length: 500, width: 300, quantity: 1 } ] }
  end

  def sign_in_user
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  def enqueued_limit_reached_job
    ActiveJob::Base.queue_adapter.enqueued_jobs.find { |j| j[:job] == BrevoTrackEventJob }
  end

  def enqueued_properties
    args = enqueued_limit_reached_job[:args].first
    args.is_a?(Hash) ? args.deep_symbolize_keys[:properties] : {}
  end

  before do
    sign_in_user
    allow(RustCuttingService).to receive(:optimize).and_return(
      { "sheet_count" => 1, "waste_percent" => 5.0, "sheets" => [] }
    )
  end

  shared_examples "enqueues limit_reached event with complete properties" do |expected_limit_type|
    it "enqueues the job" do
      expect { trigger_action }.to have_enqueued_job(BrevoTrackEventJob)
        .with(hash_including(event_name: "limit_reached", email: user.email))
    end

    it "includes all required properties" do
      trigger_action

      props = enqueued_properties
      REQUIRED_LIMIT_REACHED_PROPERTIES.each do |key|
        expect(props[key]).to be_present, "Expected properties[:#{key}] to be present"
      end
    end

    it "sets limit_type to '#{expected_limit_type}'" do
      trigger_action
      expect(enqueued_properties[:limit_type]).to eq(expected_limit_type)
    end
  end

  describe "optimization limit reached" do
    before do
      10.times do
        opt = project.optimizations.new(status: "completed", result: {}, sheets_count: 1)
        opt.save!
      end
    end

    let(:trigger_action) { patch project_path(project.token), params: valid_params }

    include_examples "enqueues limit_reached event with complete properties", "optimization"
  end

  describe "project limit reached" do
    before do
      project  # force lazy let — counts as first active project
      user.projects.create!(name: "Second Project", sheet_length: 2440, sheet_width: 1220)
    end

    let(:trigger_action) { post projects_path, params: valid_params.merge(name: "Third Project") }

    include_examples "enqueues limit_reached event with complete properties", "project"
  end

  describe "pdf export limit reached" do
    before do
      project.optimizations.create!(status: "completed", result: { "sheets" => [] }, sheets_count: 1)
      3.times { user.pdf_exports.create!(project: project) }
    end

    let(:trigger_action) { get export_pdf_project_path(project.token) }

    include_examples "enqueues limit_reached event with complete properties", "pdf_export"
  end
end
