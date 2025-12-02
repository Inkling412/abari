import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/modal/agregar_proveedor_modal.dart';
import 'package:abari/modal/editar_proveedor_modal.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  List<Map<String, dynamic>> proveedores = [];
  List<Map<String, dynamic>> filtrados = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarProveedores();
    _searchController.addListener(filtrar);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> cargarProveedores() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('proveedor')
          .select(
            'id_proveedor, nombre_proveedor, ruc_proveedor, numero_telefono',
          );

      if (mounted) {
        setState(() {
          proveedores = List<Map<String, dynamic>>.from(response);
          filtrados = proveedores;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar proveedores: $e')),
        );
      }
    }
  }

  void filtrar() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filtrados = proveedores.where((p) {
        final nombre = p['nombre_proveedor']?.toLowerCase() ?? '';
        final ruc = p['ruc_proveedor']?.toLowerCase() ?? '';
        final telefono = p['numero_telefono']?.toLowerCase() ?? '';
        return nombre.contains(query) ||
            ruc.contains(query) ||
            telefono.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 50),
          child: Column(
            children: [
              // Header con título y contador
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.business, size: 28, color: Colors.purple[700]),
                    const SizedBox(width: 12),
                    const Text(
                      'Proveedores',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filtrados.length} registros',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, RUC o teléfono...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              filtrar();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  ),
                ),
              ),
              // Lista
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No hay proveedores registrados'
                                  : 'No se encontraron resultados',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: cargarProveedores,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtrados.length,
                          itemBuilder: (context, index) {
                            final proveedor = filtrados[index];
                            final ruc = proveedor['ruc_proveedor'] as String?;
                            final telefono =
                                proveedor['numero_telefono'] as String?;
                            final tieneRuc = ruc != null && ruc.isNotEmpty;
                            final tieneTelefono =
                                telefono != null && telefono.isNotEmpty;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isDark ? 2 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                  width: 0.5,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.business,
                                    color: Colors.purple[700],
                                  ),
                                ),
                                title: Text(
                                  proveedor['nombre_proveedor'] ?? 'Sin nombre',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: (tieneRuc || tieneTelefono)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          if (tieneRuc)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.badge_outlined,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'RUC: $ruc',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (tieneRuc && tieneTelefono)
                                            const SizedBox(height: 2),
                                          if (tieneTelefono)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.phone_outlined,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  telefono,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      )
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => mostrarEditarProveedor(
                                    context,
                                    proveedor,
                                    cargarProveedores,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarAgregarProveedor(context, cargarProveedores),
        icon: const Icon(Icons.add_business),
        label: const Text('Agregar'),
      ),
    );
  }
}
