// Weather data models — ported from Weather_App-master

class WCoord {
  final double? lon;
  final double? lat;
  WCoord({this.lon, this.lat});
  factory WCoord.fromJson(dynamic json) {
    if (json == null) return WCoord();
    return WCoord(
      lon: (json['lon'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
    );
  }
}

class WClouds {
  final int? all;
  WClouds({this.all});
  factory WClouds.fromJson(dynamic json) {
    if (json == null) return WClouds();
    return WClouds(all: json['all']);
  }
}

class WSys {
  final int? type;
  final int? id;
  final String? country;
  final int? sunrise;
  final int? sunset;
  WSys({this.type, this.id, this.country, this.sunrise, this.sunset});
  factory WSys.fromJson(dynamic json) {
    if (json == null) return WSys();
    return WSys(
      type: json['type'],
      id: json['id'],
      country: json['country'],
      sunrise: json['sunrise'],
      sunset: json['sunset'],
    );
  }
}

class WWeatherCondition {
  final int? id;
  final String? main;
  final String? description;
  final String? icon;
  WWeatherCondition({this.id, this.main, this.description, this.icon});
  factory WWeatherCondition.fromJson(dynamic json) {
    if (json == null) return WWeatherCondition();
    return WWeatherCondition(
      id: json['id'],
      main: json['main'],
      description: json['description'],
      icon: json['icon'],
    );
  }
}

class WMainWeather {
  final double? temp;
  final double? feelsLike;
  final double? tempMin;
  final double? tempMax;
  final int? pressure;
  final int? humidity;
  WMainWeather({
    this.temp,
    this.feelsLike,
    this.tempMin,
    this.tempMax,
    this.pressure,
    this.humidity,
  });
  factory WMainWeather.fromJson(dynamic json) {
    if (json == null) return WMainWeather();
    return WMainWeather(
      temp: (json['temp'] as num?)?.toDouble(),
      feelsLike: (json['feels_like'] as num?)?.toDouble(),
      tempMin: (json['temp_min'] as num?)?.toDouble(),
      tempMax: (json['temp_max'] as num?)?.toDouble(),
      pressure: json['pressure'],
      humidity: json['humidity'],
    );
  }
}

class WWind {
  final double? speed;
  final int? deg;
  WWind({this.speed, this.deg});
  factory WWind.fromJson(dynamic json) {
    if (json == null) return WWind();
    return WWind(
      speed: (json['speed'] as num?)?.toDouble(),
      deg: json['deg'],
    );
  }
}

class WCurrentWeatherData {
  final WCoord? coord;
  final List<WWeatherCondition>? weather;
  final String? base;
  final WMainWeather? main;
  final int? visibility;
  final WWind? wind;
  final WClouds? clouds;
  final int? dt;
  final WSys? sys;
  final int? timezone;
  final int? id;
  final String? name;
  final int? cod;

  WCurrentWeatherData({
    this.coord,
    this.weather,
    this.base,
    this.main,
    this.visibility,
    this.wind,
    this.clouds,
    this.dt,
    this.sys,
    this.timezone,
    this.id,
    this.name,
    this.cod,
  });

  factory WCurrentWeatherData.fromJson(dynamic json) {
    if (json == null) return WCurrentWeatherData();
    return WCurrentWeatherData(
      coord: WCoord.fromJson(json['coord']),
      weather: (json['weather'] as List?)
          ?.map((w) => WWeatherCondition.fromJson(w))
          .toList(),
      base: json['base'],
      main: WMainWeather.fromJson(json['main']),
      visibility: json['visibility'],
      wind: WWind.fromJson(json['wind']),
      clouds: WClouds.fromJson(json['clouds']),
      dt: json['dt'],
      sys: WSys.fromJson(json['sys']),
      timezone: json['timezone'],
      id: json['id'],
      name: json['name'],
      cod: json['cod'],
    );
  }

  static WCurrentWeatherData sample(
      String name, double temp, double min, double max) {
    return WCurrentWeatherData(
      name: name,
      weather: [
        WWeatherCondition(
          id: 801,
          main: 'Clouds',
          description: 'scattered clouds',
          icon: '03d',
        )
      ],
      main: WMainWeather(
        temp: temp + 273.15,
        tempMin: min + 273.15,
        tempMax: max + 273.15,
        feelsLike: temp + 273.15,
        pressure: 1012,
        humidity: 58,
      ),
      wind: WWind(speed: 3.2, deg: 120),
    );
  }
}

class WFiveDayData {
  final String? dateTime;
  final int? temp;
  WFiveDayData({this.dateTime, this.temp});
  factory WFiveDayData.fromJson(dynamic json) {
    if (json == null) return WFiveDayData();
    final dtTxt = json['dt_txt'] as String? ?? '';
    final parts = dtTxt.split(' ');
    final day = parts.isNotEmpty ? parts[0].split('-').last : '';
    final hour = parts.length > 1 ? parts[1].split(':').first : '';
    return WFiveDayData(
      dateTime: '$day-$hour',
      temp: ((json['main']['temp'] as num).toDouble() - 273.15).round(),
    );
  }
}
