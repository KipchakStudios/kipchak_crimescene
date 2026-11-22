function L(key, ...)
    local dict = Locales[Config.Locale] or Locales.en
    local str = dict[key] or Locales.en[key] or key
    if select('#', ...) > 0 then
        return str:format(...)
    end
    return str
end

function MarkerModel(number)
    return Config.Markers.Models[number] or Config.Markers.Model
end
