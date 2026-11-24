import '../models/adicional.dart';
import '../models/categoria.dart';
import '../models/codigo_promocional.dart';
import '../models/config_taller.dart';
import '../models/repuesto.dart';
import '../models/servicio.dart';

/// Catálogo de ejemplo (sin Supabase o con la base vacía). Datos de
/// ejemplo, no reales. Panel → Perfil → "Cargar datos de ejemplo" los sube.
abstract final class CatalogoLocal {
  static const config = ConfigTaller(
    nombre: 'Smart Taller',
    razonSocial: 'Smart Taller E.I.R.L. (ejemplo)',
    ruc: '20601234565',
    ciudad: 'Huancayo',
    direccion: 'Av. Ferrocarril 1250, Huancayo',
    horario: 'Lun a Sáb · 08:00 – 19:00',
    recargoDomicilioCentimos: 3000,
    whatsapp: '964000111',
    numeroYape: '964000111',
    numeroPlin: '964000111',
    metaHorasServicio: 4,
    bahias: 3,
    mecanicos: ['J. Quispe', 'L. Veliz', 'C. Mayta', 'J. Gabriel'],
  );

  static const categorias = <Categoria>[
    Categoria(id: 'lubricacion', nombre: 'Lubricación', orden: 1),
    Categoria(id: 'frenos', nombre: 'Frenos', orden: 2),
    Categoria(id: 'electrico', nombre: 'Eléctrico', orden: 3),
    Categoria(id: 'suspension', nombre: 'Suspensión y llantas', orden: 4),
    Categoria(id: 'mantenimiento', nombre: 'Mantenimiento', orden: 5),
    Categoria(id: 'rep-lubricantes', nombre: 'Lubricantes', tipo: Categoria.tipoRepuesto, orden: 10),
    Categoria(id: 'rep-filtros', nombre: 'Filtros', tipo: Categoria.tipoRepuesto, orden: 11),
    Categoria(id: 'rep-frenos', nombre: 'Frenos', tipo: Categoria.tipoRepuesto, orden: 12),
    Categoria(id: 'rep-electrico', nombre: 'Eléctrico', tipo: Categoria.tipoRepuesto, orden: 13),
    Categoria(id: 'rep-kits', nombre: 'Kits', tipo: Categoria.tipoRepuesto, orden: 14),
  ];

  static PrecioVehiculo _p(String clave, int soles, int minutos) =>
      PrecioVehiculo(clave: clave, precioCentimos: soles * 100, minutos: minutos);

  static Map<String, PrecioVehiculo> _precios(int auto, int suv, int pesado, {int minutos = 60}) => {
    TiposVehiculo.auto: _p(TiposVehiculo.auto, auto, minutos),
    TiposVehiculo.suv: _p(TiposVehiculo.suv, suv, (minutos * 1.25).round()),
    TiposVehiculo.pesado: _p(TiposVehiculo.pesado, pesado, (minutos * 1.5).round()),
  };

  static final servicios = <Servicio>[
    Servicio(
      id: 'cambio-aceite',
      nombre: 'Cambio de aceite y filtros',
      subtitulo: 'Mano de obra · aceite y filtros aparte',
      categoriaIds: const ['lubricacion', 'mantenimiento'],
      precios: _precios(40, 50, 60, minutos: 45),
      popular: true,
      adicionalIds: const ['lavado-motor', 'revision-21'],
      garantiaDias: 30,
      intervaloKm: 5000,
    ),
    Servicio(
      id: 'pastillas-freno',
      nombre: 'Cambio de pastillas de freno',
      subtitulo: 'Mano de obra · eje delantero',
      categoriaIds: const ['frenos'],
      precios: _precios(60, 75, 90, minutos: 90),
      popular: true,
      adicionalIds: const ['revision-21'],
      garantiaDias: 90,
      intervaloKm: 30000,
    ),
    Servicio(
      id: 'rectificado-discos',
      nombre: 'Rectificado de discos',
      subtitulo: 'Par de discos',
      categoriaIds: const ['frenos'],
      precios: _precios(140, 160, 180, minutos: 60),
      garantiaDias: 30,
    ),
    Servicio(
      id: 'diagnostico-escaner',
      nombre: 'Diagnóstico electrónico con escáner',
      subtitulo: 'Lectura y borrado de códigos',
      categoriaIds: const ['electrico'],
      precios: _precios(50, 50, 60, minutos: 30),
      popular: true,
    ),
    Servicio(
      id: 'cambio-bateria',
      nombre: 'Cambio de batería',
      subtitulo: 'Mano de obra · prueba de carga incluida',
      categoriaIds: const ['electrico'],
      precios: _precios(30, 30, 40, minutos: 20),
      garantiaDias: 365,
    ),
    Servicio(
      id: 'alineamiento-balanceo',
      nombre: 'Alineamiento y balanceo',
      subtitulo: '4 ruedas',
      categoriaIds: const ['suspension', 'mantenimiento'],
      precios: _precios(120, 140, 160, minutos: 60),
      popular: true,
      intervaloKm: 10000,
    ),
    Servicio(
      id: 'mantenimiento-preventivo',
      nombre: 'Mantenimiento preventivo',
      subtitulo: 'Mano de obra según km (10k, 20k, 50k…)',
      categoriaIds: const ['mantenimiento'],
      precios: _precios(90, 110, 130, minutos: 150),
      adicionalIds: const ['lavado-motor', 'revision-21', 'limpieza-inyectores'],
      garantiaDias: 30,
      intervaloKm: 10000,
    ),
    Servicio(
      id: 'cambio-bujias',
      nombre: 'Cambio de bujías',
      subtitulo: 'Juego completo',
      categoriaIds: const ['electrico', 'mantenimiento'],
      precios: _precios(45, 55, 65, minutos: 40),
      descuentoPorcentaje: 10,
      intervaloKm: 40000,
    ),
  ];

  static const adicionales = <Adicional>[
    Adicional(id: 'lavado-motor', nombre: 'Lavado de motor', precioCentimos: 2500),
    Adicional(id: 'revision-21', nombre: 'Revisión de 21 puntos', precioCentimos: 1500),
    Adicional(id: 'limpieza-inyectores', nombre: 'Limpieza de inyectores', precioCentimos: 8000),
  ];

  static const repuestos = <Repuesto>[
    Repuesto(codigo: 'LUB-1040', nombre: 'Aceite 10W-40 sintético 1L', categoriaId: 'rep-lubricantes', precioCentimos: 3700, stock: 48, minimo: 20),
    Repuesto(codigo: 'FIL-TY02', nombre: 'Filtro de aceite Toyota', categoriaId: 'rep-filtros', precioCentimos: 4200, stock: 6, minimo: 10),
    Repuesto(codigo: 'FIL-AI03', nombre: 'Filtro de aire', categoriaId: 'rep-filtros', precioCentimos: 5500, stock: 14, minimo: 6),
    Repuesto(codigo: 'FRE-HY11', nombre: 'Pastillas de freno Accent', categoriaId: 'rep-frenos', precioCentimos: 26000, stock: 3, minimo: 8),
    Repuesto(codigo: 'BAT-7500', nombre: 'Batería 12V 75Ah', categoriaId: 'rep-electrico', precioCentimos: 35000, stock: 11, minimo: 6),
    Repuesto(codigo: 'FRE-DOT4', nombre: 'Líquido de frenos DOT4', categoriaId: 'rep-frenos', precioCentimos: 6000, stock: 2, minimo: 12),
    Repuesto(codigo: 'ENC-IR04', nombre: 'Bujías iridio (juego)', categoriaId: 'rep-electrico', precioCentimos: 14500, stock: 22, minimo: 10),
    Repuesto(codigo: 'KIT-MP50', nombre: 'Kit de mantenimiento 50,000 km', categoriaId: 'rep-kits', precioCentimos: 48000, stock: 5, minimo: 2),
  ];

  static final promociones = <CodigoPromocional>[
    const CodigoPromocional(
      codigo: 'AUTOSIGLO10',
      tipo: CodigoPromocional.porcentaje,
      valor: 10,
      minimoSubtotalCentimos: 15000,
      descripcion: '10% en órdenes desde S/ 150',
    ),
    const CodigoPromocional(
      codigo: 'FRENOS20',
      tipo: CodigoPromocional.fijo,
      valor: 2000,
      minimoSubtotalCentimos: 20000,
      descripcion: 'S/ 20 menos en servicios de frenos desde S/ 200',
    ),
    CodigoPromocional(
      codigo: 'FLOTA15',
      tipo: CodigoPromocional.porcentaje,
      valor: 15,
      minimoSubtotalCentimos: 50000,
      maxUsos: 50,
      venceEn: DateTime(2027, 12, 31),
      descripcion: 'Empresas con flota: 15% desde S/ 500',
    ),
  ];
}
