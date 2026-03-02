enum AppLogLevel {
  debug(10, 'DEBUG'),
  info(20, 'INFO'),
  warn(30, 'WARN'),
  error(40, 'ERROR');

  const AppLogLevel(this.weight, this.label);

  final int weight;
  final String label;
}
