// lib/features/gallery/services/unsupported_address_searcher.dart

import 'package:flutter/material.dart';

class AddressSearcher {
  void search(BuildContext context, {required ValueChanged<String> onAddressSelected}) {
    throw UnsupportedError('Address search is not supported on this platform.');
  }
}