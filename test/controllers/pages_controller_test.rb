require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
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
end
