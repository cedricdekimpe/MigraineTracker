require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "the urgent-care page is public and lists both levels of urgency" do
    get urgent_path(locale: :fr)
    assert_response :success
    assert_select "[data-urgency=emergency] li", minimum: 4
    assert_select "[data-urgency=soon] li", minimum: 6
    assert_match(/112/, response.body)
    assert_match(/pas un diagnostic/, response.body)
  end

  test "it exists in English too, and is linked from the footer and the first screen" do
    get urgent_path(locale: :en)
    assert_match(/thunderclap/, response.body)
    assert_select "footer a[href=?]", urgent_path(locale: :en)

    get root_path(locale: :en)
    assert_select "a[href=?]", urgent_path(locale: :en), minimum: 1
  end

  test "'Understand my figures' needs an account and explains each statistic with its source" do
    get numbers_path(locale: :fr)
    assert_redirected_to new_user_session_path

    sign_in users(:one)
    get numbers_path(locale: :fr)
    assert_response :success
    %w[days limits acute preventive chronic menstrual factors].each { |anchor| assert_select "section##{anchor} h2" }
    assert_select "section", 7
    assert_select "section#limits p.text-xs", text: /INAMI/
    assert_match(/pas un avis médical/, response.body)
  end

  test "the statistics folds its explanations behind an info button that leads to the page" do
    sign_in users(:one)
    get stats_path(locale: :en)
    assert_select "details[data-info] summary", minimum: 2
    assert_select "details[data-info] a[href=?]", numbers_path(locale: :en), minimum: 1
    assert_select "[data-info] a[href=?]", numbers_path(locale: :en, anchor: "limits")
  end

  test "the statistics carries the medical disclaimer once, at the bottom" do
    sign_in users(:one)
    get stats_path(locale: :en)
    assert_equal 1, response.body.scan("not medical advice or a diagnosis").size
    assert_no_match(/not a diagnosis/, response.body.gsub("not medical advice or a diagnosis", ""))
  end

  test "the journal legend is folded" do
    sign_in users(:one)
    get episodes_path(locale: :en)
    assert_select "details[data-legend]:not([open])"
  end

  test "the first screen is the form and a short pitch, without the long sales copy" do
    get root_path(locale: :fr)
    assert_select "ul li[itemprop=featureList]", 3
    assert_select "article p", maximum: 4
    assert_no_match(/Prêt à commencer le suivi/, response.body)
  end
end
