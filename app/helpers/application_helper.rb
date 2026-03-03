module ApplicationHelper
  # Maps each feature to the minimum plan that includes it.
  # Relies on PLANS hash insertion order: free → worker → enterprise.
  FEATURE_PLAN_MAP = Plannable::PLANS.each_with_object({}) do |(plan_key, config), map|
    config[:features].each { |feature| map[feature] ||= plan_key }
  end.freeze

  def feature_locked?(feature)
    !has_feature?(feature)
  end

  # Renders a small rocket icon with hover tooltip showing plan name + monthly price.
  # Returns nil if the user already has the feature.
  def plan_badge_for(feature)
    return nil unless feature_locked?(feature)

    required_plan = FEATURE_PLAN_MAP[feature.to_sym]
    return nil if required_plan.nil? || required_plan == "free"

    plan_name = t("plans.#{required_plan}.name")
    price_cents = Plannable::PLANS[required_plan][:prices][:monthly][:amount]
    price_label = "#{plan_name} — #{price_cents / 100}\u20AC/#{t("plans.month")}"

    rocket_svg = '<svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 640 640" fill="currentColor">' \
                 '<path d="M192 384L88.5 384C63.6 384 48.3 356.9 61.1 335.5L114 247.3C122.7 232.8 138.3 224 155.2 224L250.2 224C326.3 95.1 439.8 88.6 515.7 99.7C528.5 101.6 538.5 111.6 540.3 124.3C551.4 200.2 544.9 313.7 416 389.8L416 484.8C416 501.7 407.2 517.3 392.7 526L304.5 578.9C283.2 591.7 256 576.3 256 551.5L256 448C256 412.7 227.3 384 192 384L191.9 384zM464 224C464 197.5 442.5 176 416 176C389.5 176 368 197.5 368 224C368 250.5 389.5 272 416 272C442.5 272 464 250.5 464 224z"/>' \
                 "</svg>"

    tag.span(class: "relative group/badge inline-flex items-center ml-1") do
      icon = tag.a(rocket_svg.html_safe,
        href: plans_path,
        class: "text-blue-400 hover:text-blue-300 transition-colors")
      tooltip = tag.span(price_label,
        class: "absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-2 py-1 text-[10px] text-white bg-gray-800 rounded shadow-lg whitespace-nowrap opacity-0 group-hover/badge:opacity-100 transition-opacity pointer-events-none")
      icon + tooltip
    end
  end
end
