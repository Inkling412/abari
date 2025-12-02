import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/modal/agregar_cliente_modal.dart';
import 'package:abari/modal/editar_cliente_modal.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Map<String, dynamic>> clientes = [];
  List<Map<String, dynamic>> filtrados = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarClientes();
    _searchController.addListener(filtrar);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> cargarClientes() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('cliente')
          .select('id_cliente, nombre_cliente, numero_telefono');

      if (mounted) {
        setState(() {
          clientes = List<Map<String, dynamic>>.from(response);
          filtrados = clientes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar clientes: $e')));
      }
    }
  }

  void filtrar() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filtrados = clientes.where((c) {
        final nombre = c['nombre_cliente']?.toLowerCase() ?? '';
        final telefono = c['numero_telefono']?.toLowerCase() ?? '';
        return nombre.contains(query) || telefono.contains(query);
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
                    Icon(Icons.people, size: 28, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    const Text(
                      'Clientes',
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
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filtrados.length} registros',
                        style: TextStyle(
                          color: Colors.green[700],
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
                    hintText: 'Buscar por nombre o teléfono...',
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
                              Icons.person_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No hay clientes registrados'
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
                        onRefresh: cargarClientes,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtrados.length,
                          itemBuilder: (context, index) {
                            final cliente = filtrados[index];
                            final telefono =
                                cliente['numero_telefono'] ?? 'Sin teléfono';

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
                                  backgroundColor: Colors.green.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.green[700],
                                  ),
                                ),
                                title: Text(
                                  cliente['nombre_cliente'] ?? 'Sin nombre',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      telefono,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => mostrarEditarCliente(
                                    context,
                                    cliente,
                                    cargarClientes,
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
        onPressed: () => mostrarAgregarCliente(context, cargarClientes),
        icon: const Icon(Icons.person_add),
        label: const Text('Agregar'),
      ),
    );
  }
}
