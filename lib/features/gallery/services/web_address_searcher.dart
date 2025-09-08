import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// AddressSearcher 클래스는 이제 _AddressSearchPage를 호출합니다.
class AddressSearcher {
  Future<void> search(BuildContext context,
      {required ValueChanged<String> onAddressSelected}) async {
    final String? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const _AddressSearchPage()),
    );

    if (result != null) {
      onAddressSelected(result);
    }
  }
}

// 카카오 API 검색 결과를 담을 모델
class _KakaoAddress {
  final String addressName;
  final String roadAddressName;
  final String buildingName;

  _KakaoAddress({required this.addressName, required this.roadAddressName, required this.buildingName});

  factory _KakaoAddress.fromJson(Map<String, dynamic> json) {
    return _KakaoAddress(
      addressName: json['address_name'] ?? '',
      roadAddressName: json['road_address']?['address_name'] ?? '',
      buildingName: json['road_address']?['building_name'] ?? '',
    );
  }

  String get fullAddress {
    String addr = roadAddressName.isNotEmpty ? roadAddressName : addressName;
    if (buildingName.isNotEmpty) {
      addr += ' ($buildingName)';
    }
    return addr;
  }
}

// 주소 검색 UI와 API 호출 로직을 담은 위젯
class _AddressSearchPage extends StatefulWidget {
  const _AddressSearchPage();

  @override
  State<_AddressSearchPage> createState() => __AddressSearchPageState();
}

class __AddressSearchPageState extends State<_AddressSearchPage> {
  final _controller = TextEditingController();
  List<_KakaoAddress> _results = [];
  bool _isLoading = false;
  String _message = '검색어를 입력해주세요.';

  // 🚨 중요: 이 API 키는 보안을 위해 서버나 환경 변수로 관리하는 것이 좋습니다.
  final String _apiKey = 'ec425f8eaa0fe430be231d6b63f89db7';

  Future<void> _searchAddress(String keyword) async {
    if (keyword.length < 2) {
      setState(() {
        _results = [];
        _message = '두 글자 이상 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '주소를 검색 중입니다...';
    });

    final url = Uri.parse('https://dapi.kakao.com/v2/local/search/address.json?query=${Uri.encodeComponent(keyword)}');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'KakaoAK $_apiKey'},
      );

      if (response.statusCode == 200) {
        // UTF-8로 디코딩하여 한글 깨짐 방지
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (data['documents'] != null) {
          final List<dynamic> docList = data['documents'];
          setState(() {
            _results = docList.map((e) => _KakaoAddress.fromJson(e)).toList();
            _message = _results.isEmpty ? '검색 결과가 없습니다.' : '';
          });
        } else {
           setState(() => _message = '검색 결과가 없습니다.');
        }
      } else {
         final errorData = json.decode(utf8.decode(response.bodyBytes));
         setState(() => _message = '주소 검색 실패: ${errorData['message']}');
      }
    } catch (e) {
      setState(() => _message = '주소 검색 중 오류가 발생했습니다.');
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 검색'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '도로명, 건물명, 지번으로 검색',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchAddress(_controller.text),
                ),
              ),
              onSubmitted: _searchAddress,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(child: Text(_message))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final juso = _results[index];
                          return ListTile(
                            title: Text(juso.roadAddressName.isNotEmpty ? juso.roadAddressName : juso.addressName),
                            subtitle: juso.roadAddressName.isNotEmpty ? Text('[지번] ${juso.addressName}') : null,
                            onTap: () {
                              Navigator.pop(context, juso.fullAddress);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}