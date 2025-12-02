<div align="center">

# 🏪 ABARI

### Aplicacion inteligente de gestion de inventario y prediccion de ventas

[![Flutter](https://img.shields.io/badge/Flutter-3.9+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](LICENSE)

<p align="center">
  <strong>Una solución completa para la gestión de inventarios, ventas y compras de tu negocio</strong>
</p>

---

</div>

## 📋 Descripción

**ABARI** es una aplicación multiplataforma desarrollada en Flutter que proporciona una solución integral para la gestión comercial de pequeñas y medianas empresas. Con una interfaz moderna e intuitiva, permite administrar inventarios, procesar ventas, gestionar compras y generar reportes detallados, todo respaldado por Supabase como backend en la nube.

---

## ✨ Características Principales

### 📦 Gestión de Inventario
- **Catálogo de productos** con búsqueda avanzada y filtros por categoría
- **Control de stock** en tiempo real con alertas de stock bajo
- **Seguimiento de vencimientos** con notificaciones de productos próximos a vencer
- **Múltiples presentaciones** (unidad, granel, paquete, etc.)
- **Paginación inteligente** para manejar grandes volúmenes de productos

### 🛒 Punto de Venta (Facturación)
- **Proceso de venta guiado** en 3 pasos intuitivos
- **Selección rápida de productos** con búsqueda en tiempo real
- **Múltiples métodos de pago** soportados
- **Gestión de clientes** integrada
- **Generación de facturas** en formato PDF

### 📥 Gestión de Compras
- **Registro de compras** a proveedores
- **Creación de productos** directamente desde la compra
- **Duplicación de productos** para agilizar el ingreso
- **Historial de compras** completo

### 👥 Gestión de Entidades
- **Clientes**: Registro y seguimiento de clientes
- **Proveedores**: Catálogo de proveedores con información de contacto
- **Empleados**: Control de usuarios y sesiones

### 📊 Dashboard y Reportes
- **Panel de control** con estadísticas en tiempo real:
  - Total de productos disponibles
  - Productos próximos a vencer
  - Productos con stock bajo
  - Ventas del día y del mes
  - Compras del mes
  - Total de clientes y proveedores
- **Gráficas interactivas** de ganancias vs gastos
- **Predicción de ventas** con Machine Learning para los próximos 30 días
- **Reportes de ventas** con filtros por fecha y exportación a PDF
- **Reportes de compras** detallados

### 🎨 Experiencia de Usuario
- **Tema claro/oscuro** con persistencia de preferencias
- **Diseño Material 3** moderno y adaptativo
- **Navegación fluida** con Go Router
- **Sesión persistente** para recordar el empleado activo
- **Soporte multiidioma** (Español/Inglés)

---

## 🛠️ Stack Tecnológico

| Tecnología | Uso |
|------------|-----|
| **Flutter 3.9+** | Framework de desarrollo multiplataforma |
| **Dart 3.0+** | Lenguaje de programación |
| **Supabase** | Backend as a Service (Auth, Database, Storage) |
| **Provider** | Gestión de estado |
| **Go Router** | Navegación declarativa |
| **FL Chart** | Gráficas y visualizaciones |
| **PDF & Printing** | Generación de documentos PDF |
| **SharedPreferences** | Almacenamiento local de preferencias |

---

## 📱 Plataformas Soportadas

| Plataforma | Estado |
|------------|--------|
| 🤖 Android | ✅ Soportado |
| 🍎 iOS | ✅ Soportado |
| 🪟 Windows | ✅ Soportado |
| 🐧 Linux | ✅ Soportado |
| 🍏 macOS | ✅ Soportado |
| 🌐 Web | ✅ Soportado |

---

## 🚀 Instalación

### Prerrequisitos

- Flutter SDK 3.9 o superior
- Dart SDK 3.0 o superior
- Cuenta de Supabase configurada

### Pasos de instalación

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-usuario/abari.git

# 2. Navegar al directorio del proyecto
cd abari

# 3. Instalar dependencias
flutter pub get

# 4. Ejecutar la aplicación
flutter run
```

### Configuración de Supabase

La aplicación ya viene preconfigurada con las credenciales de Supabase. Si deseas usar tu propia instancia:

1. Crea un proyecto en [Supabase](https://supabase.com)
2. Actualiza las credenciales en `lib/main.dart`:
   ```dart
   await Supabase.initialize(
     url: 'TU_SUPABASE_URL',
     anonKey: 'TU_ANON_KEY',
   );
   ```

---

## 📂 Estructura del Proyecto

```
lib/
├── main.dart              # Punto de entrada de la aplicación
├── router.dart            # Configuración de rutas
├── models/                # Modelos de datos
├── providers/             # Gestión de estado (Provider)
│   ├── session_provider.dart
│   ├── theme_provider.dart
│   ├── factura_provider.dart
│   └── compra_provider.dart
├── screens/               # Pantallas de la aplicación
│   ├── home_screen.dart   # Dashboard principal
│   ├── login_screen.dart  # Autenticación
│   ├── productos.dart     # Gestión de inventario
│   ├── compras.dart       # Registro de compras
│   ├── clientes.dart      # Gestión de clientes
│   ├── proveedores.dart   # Gestión de proveedores
│   ├── empleados.dart     # Gestión de empleados
│   ├── factura/           # Módulo de facturación
│   ├── reporte_venta_screen.dart
│   └── reporte_compra_screen.dart
├── services/              # Servicios (API, predicciones)
├── widgets/               # Componentes reutilizables
│   ├── app_shell.dart     # Layout principal con navegación
│   └── prediccion_chart.dart
└── modal/                 # Diálogos y modales
```

---

## 🔐 Autenticación

ABARI utiliza Supabase Auth para la autenticación de usuarios:

- **Login con email/contraseña**
- **Sesiones persistentes**
- **Protección de rutas** automática
- **Cierre de sesión** seguro

---

## 📈 Predicción de Ventas

El sistema incluye un módulo de **predicción de ventas** que utiliza Machine Learning para proyectar las ventas de los próximos 30 días, ayudando a:

- Planificar el inventario
- Anticipar la demanda
- Tomar decisiones basadas en datos

---

## 🎯 Roadmap

- [ ] Sincronización offline
- [ ] Notificaciones push
- [ ] Integración con impresoras térmicas
- [ ] Módulo de cuentas por cobrar
- [ ] Dashboard de analytics avanzado
- [ ] API REST para integraciones


## 📄 Licencia

Este proyecto es software propietario. Todos los derechos reservados.

---

<div align="center">

**Desarrollado por Enrique Urbina y Miguel Hernandez usando Flutter**

</div>
