class InsuranceService {

  double calcularSeguro(double valor) {

    if (valor <= 1000) return 15;

    if (valor <= 5000) return 20;

    return 25;
  }
}