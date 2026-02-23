require "rails_helper"

RSpec.describe "Locale switching", type: :request do
  describe "guest (logged out)" do
    it "defaults to English when no Accept-Language header" do
      get root_path
      expect(response.body).to include(I18n.t("sidebar.new_cut_list", locale: :en))
    end

    it "detects French from Accept-Language header" do
      get root_path, headers: { "Accept-Language" => "fr-FR,fr;q=0.9,en;q=0.8" }
      expect(response.body).to include(I18n.t("sidebar.new_cut_list", locale: :fr))
    end

    it "detects Japanese from Accept-Language header" do
      get root_path, headers: { "Accept-Language" => "ja,en;q=0.5" }
      expect(response.body).to include(I18n.t("sidebar.new_cut_list", locale: :ja))
    end

    it "falls back to English for unsupported languages" do
      get root_path, headers: { "Accept-Language" => "de-DE,de;q=0.9" }
      expect(response.body).to include(I18n.t("sidebar.new_cut_list", locale: :en))
    end

    it "picks the first supported locale from a multi-language header" do
      get root_path, headers: { "Accept-Language" => "de-DE,ja;q=0.8,fr;q=0.7" }
      expect(response.body).to include(I18n.t("sidebar.new_cut_list", locale: :ja))
    end
  end

  describe "logged-in user" do
    let(:user) do
      User.create!(
        email: "locale-test@example.com",
        password: "password123",
        password_confirmation: "password123",
        terms_accepted: true
      )
    end

    before { sign_in user }

    it "uses the browser locale when user has no saved locale" do
      get root_path, headers: { "Accept-Language" => "fr" }
      expect(response.body).to include(I18n.t("sidebar.new_cut_list", locale: :fr))
    end

    describe "PATCH /locale" do
      it "saves locale to the user record in the database" do
        patch locale_path, params: { locale: "fr" }, headers: { "Referer" => root_url }

        user.reload
        expect(user.locale).to eq("fr")
      end

      it "persists the locale across subsequent requests" do
        patch locale_path, params: { locale: "ja" }, headers: { "Referer" => root_url }
        follow_redirect!

        expect(response.body).to include(I18n.t("sidebar.new_cut_list", locale: :ja))
      end

      it "ignores invalid locale values" do
        patch locale_path, params: { locale: "xx" }, headers: { "Referer" => root_url }

        user.reload
        expect(user.locale).to be_nil
      end
    end

    it "prefers user's saved locale over browser Accept-Language" do
      user.update!(locale: "ja")

      get root_path, headers: { "Accept-Language" => "fr" }
      expect(response.body).to include(I18n.t("sidebar.new_cut_list", locale: :ja))
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
