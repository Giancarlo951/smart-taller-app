import '../../../core/utils/formatos.dart';
import '../../../core/utils/validadores.dart';
import '../../cuentas/models/rol.dart';
import '../../cuentas/services/permisos.dart';
import '../models/orden.dart';

/// Reglas de negocio de la orden de trabajo (funciones puras, con tests).
/// Devuelven el mensaje de error o null si la acción está permitida.
abstract final class ReglasOrden {
  /// Boletas desde este monto necesitan el DNI del cliente (SUNAT).
  static const boletaConDniDesdeCentimos = 70000;

  /// Registrar avance / cambio de etapa / anular.
  static String? validarCambio(Orden orden, EstadoOrden destino, Rol rol) {
    if (!orden.estado.activa) {
      return 'La orden ${orden.codigo} ya está ${orden.estado.etiqueta.toLowerCase()}';
    }
    if (destino == EstadoOrden.cancelado) {
      if (!Permisos.puedeAnularOrden(rol)) {
        return 'Solo el jefe de taller o administración pueden anular una orden';
      }
      if (orden.estaPagada || orden.tieneComprobante) {
        return 'La orden ya tiene un cobro registrado: emite una nota de crédito';
      }
      return null;
    }
    if (destino == EstadoOrden.entregado) {
      if (orden.estado != EstadoOrden.listo) {
        return 'El vehículo se entrega cuando la orden está lista';
      }
      if (!Permisos.puedeEntregarVehiculo(rol)) {
        return 'Solo el jefe de taller o administración entregan el vehículo';
      }
      if (!orden.estaPagada) return 'Registra el cobro antes de entregar el vehículo';
      return null;
    }
    if (destino.indice <= orden.estado.indice) {
      return 'La orden ya pasó por ${destino.titulo}';
    }
    if (destino == EstadoOrden.listo && !Permisos.puedeCompletarOrden(rol)) {
      return 'Solo el jefe de taller puede marcar la orden como lista para entrega';
    }
    if (orden.lineas.isEmpty && destino.indice >= EstadoOrden.reparacion.indice) {
      return 'Agrega los servicios y repuestos antes de pasar a reparación';
    }
    return null;
  }

  /// Agregar o quitar servicios y repuestos de una orden abierta.
  static String? validarEdicionLineas(Orden orden) {
    if (!orden.estado.activa) return 'La orden ${orden.codigo} ya está cerrada';
    if (orden.estado == EstadoOrden.listo) {
      return 'La orden ya está lista: vuelve a abrir una nueva para más trabajos';
    }
    if (orden.estaPagada || orden.pagoPorVerificar) {
      return 'La orden ya tiene un cobro registrado';
    }
    return null;
  }

  /// Escribir o corregir el diagnóstico: cualquier miembro del personal,
  /// mientras el vehículo siga en el taller (igual que registrar_diagnostico).
  static String? validarDiagnostico(Orden orden, String texto) {
    if (!orden.estado.activa || orden.estado == EstadoOrden.listo) {
      return 'La orden ${orden.codigo} ya no se puede editar';
    }
    final limpio = texto.trim();
    if (limpio.length < 5) return 'Escribe el diagnóstico (mínimo 5 caracteres)';
    if (limpio.length > maximoDiagnostico) return 'El diagnóstico es muy largo (máximo $maximoDiagnostico caracteres)';
    return null;
  }

  static const maximoDiagnostico = 1000;

  /// Registrar el cobro (efectivo, Yape/Plin o tarjeta).
  static String? validarCobro(Orden orden, Rol rol, {required String metodo, String? referencia}) {
    if (!Permisos.puedeCobrar(rol)) return 'Solo el jefe de taller o administración cobran';
    if (orden.estado == EstadoOrden.cancelado) return 'La orden está anulada';
    if (orden.estado != EstadoOrden.listo) {
      return 'Se cobra cuando la orden está lista para entrega';
    }
    if (orden.estaPagada) return 'La orden ${orden.codigo} ya está pagada';
    if (orden.pagoPorVerificar) return 'Hay un pago por verificar para esta orden';
    if (orden.totalCentimos <= 0) return 'La orden no tiene monto a cobrar';
    if (!MetodosPago.todos.contains(metodo)) return 'Seleccione el medio de pago';
    if (MetodosPago.esBilletera(metodo)) return Validadores.numeroOperacion(referencia);
    return null;
  }

  /// Aprobar o rechazar un Yape/Plin.
  static String? validarVerificacion(Orden orden, Rol rol) {
    if (!Permisos.puedeAprobarPago(rol)) return 'Solo administración verifica los pagos';
    if (!orden.pagoPorVerificar) return 'La orden no tiene un pago por verificar';
    return null;
  }

  /// Emitir boleta o factura electrónica.
  static String? validarComprobante(
    Orden orden,
    Rol rol, {
    required String tipo,
    String documento = '',
    String razonSocial = '',
  }) {
    if (!Permisos.puedeFacturar(rol)) return 'Solo el jefe de taller o administración facturan';
    if (orden.tieneComprobante) {
      return 'La orden ya tiene el comprobante ${orden.comprobante!.codigo}';
    }
    if (!orden.estaPagada) return 'Registra el cobro antes de emitir el comprobante';
    final doc = documento.trim();
    if (tipo == Comprobante.factura) {
      final error = Validadores.ruc(doc);
      if (error != null) return error;
      if (razonSocial.trim().length < 3) return 'Ingrese la razón social';
      return null;
    }
    if (tipo != Comprobante.boleta) return 'Seleccione boleta o factura';
    if (doc.isEmpty) {
      return orden.totalCentimos >= boletaConDniDesdeCentimos
          ? 'Boletas desde ${formatoCentimos(boletaConDniDesdeCentimos)} requieren el DNI del cliente'
          : null;
    }
    return Validadores.dni(doc);
  }
}
