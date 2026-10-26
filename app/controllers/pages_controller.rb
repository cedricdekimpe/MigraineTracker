# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:faq, :privacy, :urgent, :free, :about_ai]

  def faq
  end

  def privacy
  end

  def urgent
  end

  # "Why this tool is free" and "A word about AI": who is behind it and what it costs, in plain words.
  def free
  end

  def about_ai
  end

  # "Understand my figures": signed-in only (the default), it explains the statistics.
  def numbers
  end
end
