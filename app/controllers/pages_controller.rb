# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:faq, :privacy, :urgent]

  def faq
  end

  def privacy
  end

  def urgent
  end
end
