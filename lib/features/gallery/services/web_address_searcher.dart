// lib/features/gallery/services/web_address_searcher.dart

import 'dart:async';
import 'dart:convert'; // JSON 파싱을 위해 import
import 'dart:html' as html;
import 'package:flutter/material.dart';

class AddressSearcher {
  /// 웹 환경에서 주소 검색 팝업을 열고 결과를 처리합니다.
  void search(BuildContext context, {required ValueChanged<String> onAddressSelected}) {
    // 메시지 리스너가 중복으로 쌓이는 것을 방지하기 위해, 한 번만 수신하고 자동으로 해제되도록 합니다.
    final StreamSubscription<html.MessageEvent> subscription =
        html.window.onMessage.listen(null);

    subscription.onData((event) {
      try {
        final data = event.data;

        // 1. 전달받은 데이터(JSON 문자열)를 Map 객체로 변환합니다.
        final decodedData = jsonDecode(data as String);
        String address = '';

        // 2. 사용자가 선택한 주소 유형에 따라 주소를 할당합니다.
        if (decodedData['userSelectedType'] == 'R') {
          address = decodedData['roadAddress'] ?? '';
        } else {
          address = decodedData['jibunAddress'] ?? '';
        }

        // 3. 건물 이름(buildingName)이 있다면 주소 뒤에 추가합니다.
        final buildingName = decodedData['buildingName'];
        if (buildingName != null && buildingName.isNotEmpty) {
          address += ' ($buildingName)';
        }

        // 4. 최종 결과를 콜백 함수로 전달합니다.
        if (address.isNotEmpty) {
          onAddressSelected(address);
        }
      } catch (e) {
        print('주소 데이터 파싱 중 에러 발생: $e');
      } finally {
        // 5. 메시지를 성공적으로 처리했으므로 리스너를 해제합니다.
        subscription.cancel();
      }
    });

    // 카카오 주소 검색 HTML을 팝업으로 엽니다.
    html.window.open(
        'assets/postcode.html', 'address-search-popup', 'width=600,height=700');
  }
}