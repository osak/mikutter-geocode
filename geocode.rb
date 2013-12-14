# coding: utf-8

require 'net/http'
require 'uri'
require 'pp'

class Gdk::GeoCode < Gdk::SubParts
  regist

  def initialize(*args)
    super
    @margin = 2
    if message and not helper.visible?
      sid = helper.ssc(:expose_event, helper){
        helper.on_modify
        helper.signal_handler_disconnect(sid)
        false 
      }
    end
  end

  def render(context)
    if helper.visible? and message
      context.save {
        layout = body(context)
        context.translate(width - (layout.size[0] / Pango::SCALE) - @margin, 0)
        context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
        context.show_pango_layout(layout)
      }
    end
  end

  def message
    helper.message
  end

  def height
    if message[:geo]
      body.size[1] / Pango::SCALE
    else
      0
    end
  end
  memoize :height

  def body(context = dummy_context)
    layout = context.create_pango_layout
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.alignment = Pango::ALIGN_RIGHT
    locs = locations(message)
    if locs.size > 0
      layout.text = Plugin[:geocode]._("%<location>sから") % {location: locs.first}
    else
      layout.text = ''
    end
    layout
  end

  def locations(message)
    if message[:geo]
      lat, lng = message[:geo][:coordinates]
      @locations ||= Plugin.filtering(:geocode, lat, lng, [])[2]
    else
      @locations ||= []
    end
  end

  private :body, :locations
end

Plugin.create(:geocode) do
  filter_geocode do |lat, lng, buf|
    buf << geocode(lat, lng)
    [lat, lng, buf]
  end

  @memo = {}
  API = "http://maps.googleapis.com/maps/api/geocode/json?latlng=%<lat>f,%<lng>f&sensor=false&language=%<lang>s"
  def geocode(lat, lng)
    # To avoid unneccessary requests
    key = "%.5f,%.5f" % [lat, lng]
    if val = @memo.fetch(key, nil)
      return val
    end

    url = API % {lat: lat, lng: lng, lang: UserConfig[:geocode_lang] || "ja"}
    puts url
    result = JSON.parse(Net::HTTP.get(URI.parse(url)))
    result_list = result["results"]
    @memo[key] = 
      if result_list.size > 0
        result_list.first["formatted_address"]
      else
        ""
      end
  rescue
    error_msg = 
      result ? _("Geocoding APIがなんか失敗しました(%<status>s)") % {status: result["status"]}
             : _("Geocoding APIを呼び出せませんでした")
    activity :error, error_msg
    ""
  end

  settings _("Geocode") do
    input _("表示言語"), :geocode_lang
  end
end
