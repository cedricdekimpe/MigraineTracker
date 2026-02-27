# frozen_string_literal: true

class SitemapController < ApplicationController
  skip_before_action :authenticate_user!
  
  def index
    @pages = []
    base_url = request.base_url
    
    # Add public pages for each locale
    I18n.available_locales.each do |locale|
      # Home page
      @pages << {
        url: "#{base_url}/#{locale}",
        locale: locale,
        lastmod: Time.current,
        changefreq: 'weekly',
        priority: '1.0'
      }
      
      # FAQ page
      @pages << {
        url: "#{base_url}/#{locale}/faq",
        locale: locale,
        lastmod: Time.current,
        changefreq: 'monthly',
        priority: '0.8'
      }
    end
    
    respond_to do |format|
      format.xml
    end
  end
end
