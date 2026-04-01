require "rails_helper"

RSpec.describe User, type: :model do
  def build_user(overrides = {})
    User.new({
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(overrides))
  end

  describe "default plan on first sign-up" do
    it "assigns the free plan to a new user" do
      user = build_user
      user.save!
      expect(user.plan).to eq("free")
    end

    it "limits to 2 active projects" do
      user = build_user
      user.save!
      expect(user.max_active_projects).to eq(2)
    end

    it "limits to 20 pieces per project" do
      user = build_user
      user.save!
      expect(user.max_pieces_per_project).to eq(20)
    end

    it "limits to 3 daily PDF exports" do
      user = build_user
      user.save!
      expect(user.max_daily_pdf_exports).to eq(3)
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build_user).to be_valid
    end

    it "requires an email" do
      expect(build_user(email: "")).not_to be_valid
    end

    it "requires a valid email format" do
      expect(build_user(email: "not-an-email")).not_to be_valid
    end

    it "requires a unique email" do
      build_user.save!
      duplicate = build_user(email: "test@example.com")
      expect(duplicate).not_to be_valid
    end

    it "requires a password" do
      expect(build_user(password: "", password_confirmation: "")).not_to be_valid
    end

    it "requires password to be at least 6 characters" do
      expect(build_user(password: "short", password_confirmation: "short")).not_to be_valid
    end
  end

  describe "#should_show_feedback?" do
    def create_user_for_feedback(overrides = {})
      User.create!({
        email: "feedback-show-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        password_confirmation: "password123",
        terms_accepted: true
      }.merge(overrides))
    end

    def create_project(user)
      user.projects.create!(name: "Project #{SecureRandom.hex(4)}")
    end

    def create_optimization(project)
      Optimization.create!(project: project, result: {}, status: "completed")
    end

    def setup_qualifying_user
      user = create_user_for_feedback
      3.times { create_project(user).tap { |p| create_optimization(p) } }
      # Two extra optimizations to reach the 5-optimization threshold
      extra_project = create_project(user)
      2.times { create_optimization(extra_project) }
      user
    end

    it "returns true when all conditions are met" do
      user = setup_qualifying_user
      expect(user.should_show_feedback?).to be true
    end

    it "returns false when feedback_dismissed_at is set" do
      user = setup_qualifying_user
      user.update!(feedback_dismissed_at: Time.current)
      expect(user.should_show_feedback?).to be false
    end

    it "returns false when the user has already submitted feedback" do
      user = setup_qualifying_user
      Feedback.create!(user: user, rating: 4)
      expect(user.should_show_feedback?).to be false
    end

    it "returns false when the user has fewer than 3 projects" do
      user = create_user_for_feedback
      project = create_project(user)
      5.times { create_optimization(project) }
      # only 1 project — below FEEDBACK_MIN_PROJECTS
      expect(user.should_show_feedback?).to be false
    end

    it "returns false when the user has fewer than 5 optimizations" do
      user = create_user_for_feedback
      3.times { create_project(user).tap { |p| create_optimization(p) } }
      # 3 projects, 3 optimizations — below FEEDBACK_MIN_OPTIMIZATIONS
      expect(user.should_show_feedback?).to be false
    end

    it "returns false when the user has exactly 2 projects and 5 optimizations" do
      user = create_user_for_feedback
      project_a = create_project(user)
      3.times { create_optimization(project_a) }
      project_b = create_project(user)
      2.times { create_optimization(project_b) }
      # 2 projects — below FEEDBACK_MIN_PROJECTS
      expect(user.should_show_feedback?).to be false
    end

    it "returns false when both feedback_dismissed_at is set and feedback exists" do
      user = setup_qualifying_user
      user.update!(feedback_dismissed_at: Time.current)
      Feedback.create!(user: user, rating: 5)
      expect(user.should_show_feedback?).to be false
    end

    it "returns true at the exact thresholds (3 projects, 5 optimizations)" do
      user = create_user_for_feedback
      3.times { create_project(user) }
      # Attach 5 optimizations spread across projects
      user.projects.each_with_index do |project, i|
        create_optimization(project) if i < 2
      end
      # add remaining optimizations on the last project to reach 5 total
      remaining_project = user.projects.last
      3.times { create_optimization(remaining_project) }
      expect(user.should_show_feedback?).to be true
    end
  end
end
