// lib/features/gallery/services/address_search_service.dart

export 'unsupported_address_searcher.dart'
    if (dart.library.html) 'web_address_searcher.dart'
    if (dart.library.io) 'mobile_address_searcher.dart';