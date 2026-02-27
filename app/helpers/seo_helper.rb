# frozen_string_literal: true

module SeoHelper
  def seo_title(page_title = nil)
    base_title = t('seo.site_name', default: 'Migraine Tracker')
    if page_title.present?
      "#{page_title} | #{base_title}"
    else
      base_title
    end
  end

  def seo_description(description = nil)
    description || content_for(:description) || t('seo.default_description', default: 'Track your migraines, medications, and patterns with visual calendars designed for people living with migraines.')
  end

  def seo_image(image_url = nil)
    if image_url.present?
      image_url
    elsif content_for(:og_image).present?
      content_for(:og_image)
    else
      # Use request.base_url to get the full domain
      "#{request.base_url}#{asset_path('icon.png')}"
    end
  end

  def seo_url(path = nil)
    path || request.url
  end

  def seo_type(type = 'website')
    type
  end

  def canonical_url
    if content_for(:canonical_url).present?
      content_for(:canonical_url)
    else
      request.url
    end
  end

  def alternate_locales
    I18n.available_locales.map do |locale|
      {
        locale: locale,
        url: url_for(locale: locale, only_path: false)
      }
    end
  end

  def structured_data_organization
    {
      '@context' => 'https://schema.org',
      '@type' => 'Organization',
      'name' => t('seo.site_name', default: 'Migraine Tracker'),
      'description' => seo_description,
      'url' => root_url(locale: I18n.locale, only_path: false),
      'logo' => "#{request.base_url}#{asset_path('icon.png')}",
      'sameAs' => []
    }
  end

  def structured_data_webapp
    {
      '@context' => 'https://schema.org',
      '@type' => 'WebApplication',
      'name' => t('seo.site_name', default: 'Migraine Tracker'),
      'description' => seo_description,
      'url' => root_url(locale: I18n.locale, only_path: false),
      'applicationCategory' => 'HealthApplication',
      'operatingSystem' => 'Web',
      'offers' => {
        '@type' => 'Offer',
        'price' => '0',
        'priceCurrency' => 'USD'
      }
    }
  end
end
