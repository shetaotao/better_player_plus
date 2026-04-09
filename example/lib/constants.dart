class Constants {
  const Constants._();

  static const String bugBuckBunnyVideoUrl =
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4';
//   static const String forBiggerBlazesUrl =
//       'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
        static const String forBiggerBlazesUrl = 'https://media.w3.org/2010/05/sintel/trailer.mp4';
  static const String fileTestVideoUrl = 'trailer.mp4';
  static const String fileTestVideoEncryptUrl = 'testvideo_encrypt.mp4';
  static const String networkTestVideoEncryptUrl =
      'https://github.com/tinusneethling/betterplayer/raw/ClearKeySupport/example/assets/testvideo_encrypt.mp4';
  static const String fileExampleSubtitlesUrl = 'example_subtitles.srt';
  static const String hlsTestStreamUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  static const String hlsPlaylistUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  // static const Map<String, String> exampleResolutionsUrls = {
  //   'LOW': 'https://file-examples-com.github.io/uploads/2017/04/file_example_MP4_480_1_5MG.mp4',
  //   'MEDIUM': 'https://file-examples-com.github.io/uploads/2017/04/file_example_MP4_640_3MG.mp4',
  //   'LARGE': 'https://file-examples-com.github.io/uploads/2017/04/file_example_MP4_1280_10MG.mp4',
  //   'EXTRA_LARGE': 'https://file-examples-com.github.io/uploads/2017/04/file_example_MP4_1920_18MG.mp4',
  // };
  static const Map<String, String> exampleResolutionsUrls = {
    'LOW': 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4',
    'MEDIUM': 'https://media.w3.org/2010/05/sintel/trailer.mp4',
    'LARGE': 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_2MB.mp4',
    'EXTRA_LARGE': 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_5MB.mp4',
  };
  // HLS 测试流 - 使用较小的 HLS 流
  static const String phantomVideoUrl = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';
  // 其他 HLS 测试流选项:
  // static const String phantomVideoUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  // MP4 测试文件 - 用于测试普通文件缓存
  // static const String phantomVideoUrl = 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4';
  static const String elephantDreamVideoUrl =
      'https://media.w3.org/2010/05/sintel/trailer.mp4';
  static const String forBiggerJoyridesVideoUrl =
      'https://www.w3schools.com/html/mov_bbb.mp4';
  static const String verticalVideoUrl = 'https://cdn.pixabay.com/video/2026/02/24/336497_large.mp4';
  static String logo = 'logo.png';
  static String placeholderUrl =
      'https://imgix.bustle.com/uploads/image/2020/8/5/23905b9c-6b8c-47fa-bc0f-434de1d7e9bf-avengers-5.jpg';
      
  // static String elephantDreamStreamUrl = 'http://cdn.theoplayer.com/video/elephants-dream/playlist.m3u8';
  static String elephantDreamStreamUrl = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';
  // static String tokenEncodedHlsUrl =
  //     'https://amssamples.streaming.mediaservices.windows.net/830584f8-f0c8-4e41-968b-6538b9380aa5/TearsOfSteelTeaser.ism/manifest(format=m3u8-aapl)';
  static String tokenEncodedHlsUrl =
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  static String tokenEncodedHlsToken =
      'Bearer=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1cm46bWljcm9zb2Z0OmF6dXJlOm1lZGlhc2VydmljZXM6Y29udGVudGtleWlkZW50aWZpZXIiOiI5ZGRhMGJjYy01NmZiLTQxNDMtOWQzMi0zYWI5Y2M2ZWE4MGIiLCJpc3MiOiJodHRwOi8vdGVzdGFjcy5jb20vIiwiYXVkIjoidXJuOnRlc3QiLCJleHAiOjE3MTA4MDczODl9.lJXm5hmkp5ArRIAHqVJGefW2bcTzd91iZphoKDwa6w8';
  static String widevineVideoUrl = 'https://storage.googleapis.com/wvmedia/cenc/h264/tears/tears_sd.mpd';
  static String widevineLicenseUrl = 'https://proxy.uat.widevine.com/proxy?provider=widevine_test';
  static String fairplayHlsUrl = 'https://fps.ezdrm.com/demo/hls/BigBuckBunny_320x180.m3u8';
  static String fairplayCertificateUrl =
      'https://github.com/koldo92/betterplayer/raw/fairplay_ezdrm/example/assets/eleisure.cer';
  static String fairplayLicenseUrl = 'https://fps.ezdrm.com/api/licenses/';
  static String catImageUrl =
      'https://kimi-web-img.moonshot.cn/img/www.shutterstock.com/14185fea4b883e40ae5d90c6df73ee921ae1e22b.jpg';
  // static String dashStreamUrl = 'https://bitmovin-a.akamaihd.net/content/sintel/sintel.mpd';
  static String dashStreamUrl = 'https://dash.akamaized.net/dash264/TestCasesIOP33/adapatationSetSwitching/5/manifest.mpd';
  static String segmentedSubtitlesHlsUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
}
