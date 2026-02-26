String localizeCompanyName(String name, String code) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return code;
  }
  final mapped = _companyNameMap[trimmed.toLowerCase()];
  if (mapped != null) {
    return mapped;
  }
  return trimmed;
}

String localizeSectorName(String sector) {
  final trimmed = sector.trim();
  if (trimmed.isEmpty) {
    return '미분류';
  }
  final mapped = _sectorMap[trimmed.toLowerCase()];
  if (mapped != null) {
    return mapped;
  }
  return trimmed;
}

const Map<String, String> _companyNameMap = {
  'samsung electronics': '삼성전자',
  'samsung elec': '삼성전자',
  'sk hynix': 'SK하이닉스',
  'hynix': 'SK하이닉스',
  'lg chem': 'LG화학',
  'kia corp': '기아',
  'kia': '기아',
  'naver': '네이버',
  'hyundai motor': '현대차',
  'kb financial': 'KB금융',
  'samsung biologics': '삼성바이오로직스',
  'posco future m': '포스코퓨처엠',
  'lg energy solution': 'LG에너지솔루션',
};

const Map<String, String> _sectorMap = {
  'semiconductor': '반도체',
  'semicon': '반도체',
  'chemical': '화학',
  'auto': '자동차',
  'internet': '인터넷',
  'finance': '금융',
  'bio': '바이오',
  'biotech': '바이오',
  'battery': '2차전지',
};
