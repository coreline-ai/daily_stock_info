class UniverseStock {
  const UniverseStock({
    required this.ticker,
    required this.name,
    required this.sector,
  });

  final String ticker;
  final String name;
  final String sector;
}

const defaultUniverse = <UniverseStock>[
  UniverseStock(ticker: '005930', name: '삼성전자', sector: '반도체'),
  UniverseStock(ticker: '000660', name: 'SK하이닉스', sector: '반도체'),
  UniverseStock(ticker: '035420', name: '네이버', sector: '인터넷'),
  UniverseStock(ticker: '051910', name: 'LG화학', sector: '화학'),
  UniverseStock(ticker: '000270', name: '기아', sector: '자동차'),
  UniverseStock(ticker: '005380', name: '현대차', sector: '자동차'),
  UniverseStock(ticker: '105560', name: 'KB금융', sector: '금융'),
  UniverseStock(ticker: '207940', name: '삼성바이오로직스', sector: '바이오'),
  UniverseStock(ticker: '003670', name: '포스코퓨처엠', sector: '2차전지'),
  UniverseStock(ticker: '373220', name: 'LG에너지솔루션', sector: '2차전지'),
];
