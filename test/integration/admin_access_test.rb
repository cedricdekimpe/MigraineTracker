require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  setup do
    @regular_user = users(:one)
    @admin_user = User.create!({
      email: "admin_access@example.com",
      password: "password123",
      admin: true
    }.merge(consent_attrs))
  end

  test "guests are redirected to sign in" do
    get rails_admin_path
    assert_redirected_to new_user_session_path
  end

  test "non admin users are redirected home" do
    sign_in @regular_user, scope: :user
    get rails_admin_path
    assert_redirected_to root_path
    assert_equal I18n.t('admin.access_denied'), flash[:alert]
  end

  test "admins can view dashboard" do
    sign_in @admin_user, scope: :user
    get rails_admin_path
    assert_response :success
    assert_select "h1", text: I18n.t('admin.dashboard.title')
  end

  test "admins can access user management" do
    sign_in @admin_user, scope: :user
    get rails_admin.index_path(model_name: 'user')
    assert_response :success
  end

  test "admins can access migraine management" do
    sign_in @admin_user, scope: :user
    get rails_admin.index_path(model_name: 'migraine')
    assert_response :success
  end

  test "admins can access medication management" do
    sign_in @admin_user, scope: :user
    get rails_admin.index_path(model_name: 'medication')
    assert_response :success
  end
end
