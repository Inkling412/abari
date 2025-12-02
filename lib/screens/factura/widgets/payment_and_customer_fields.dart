import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/providers/factura_provider.dart';

class PaymentAndCustomerFields extends StatefulWidget {
  const PaymentAndCustomerFields({super.key});

  @override
  State<PaymentAndCustomerFields> createState() =>
      _PaymentAndCustomerFieldsState();
}

class _PaymentAndCustomerFieldsState extends State<PaymentAndCustomerFields> {
  // Tipo de cliente: 'general' o 'especifico'
  String _tipoCliente = 'general';

  // Para cliente específico - ID del cliente existente (null si es nuevo)
  int? _clienteSeleccionadoId;

  // Controladores para nombre y teléfono (editables)
  final _nombreClienteController = TextEditingController();
  final _telefonoClienteController = TextEditingController();

  // Flag para saber si se mostró el formulario de datos del cliente
  bool _mostrarDatosCliente = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FacturaProvider>();
      provider.cargarMetodosPago();
      provider.cargarClientes();

      // Establecer método de pago por defecto como "Efectivo"
      _setMetodoPagoPorDefecto(provider);

      // Establecer cliente general por defecto
      _setClienteGeneralPorDefecto(provider);
    });
  }

  void _setMetodoPagoPorDefecto(FacturaProvider provider) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (provider.metodosPagoCargados && provider.metodoPago.isEmpty) {
        final efectivo = provider.metodosPago.firstWhere(
          (m) => m.name.toLowerCase().contains('efectivo'),
          orElse: () => provider.metodosPago.isNotEmpty
              ? provider.metodosPago.first
              : throw Exception('No hay métodos de pago'),
        );
        provider.setMetodoPago(efectivo.name);
      }
    });
  }

  void _setClienteGeneralPorDefecto(FacturaProvider provider) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (provider.clientesCargados && provider.cliente.isEmpty) {
        // Buscar específicamente "Publico general"
        try {
          final clienteGeneral = provider.clientes.firstWhere(
            (c) => c.nombreCliente.toLowerCase() == 'publico general',
          );
          provider.setCliente(
            clienteGeneral.nombreCliente,
            clienteId: clienteGeneral.idCliente,
          );
        } catch (_) {
          // Si no existe "Publico general", no seleccionar ninguno
          // El usuario deberá seleccionar o crear un cliente
        }
      }
    });
  }

  @override
  void dispose() {
    _nombreClienteController.dispose();
    _telefonoClienteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Consumer<FacturaProvider>(
      builder: (context, provider, child) {
        final metodoPagoField = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MÉTODO DE PAGO',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            provider.isLoadingMetodosPago
                ? _buildShimmerLoader()
                : _buildMetodoPagoDropdown(provider),
          ],
        );

        final clienteField = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TIPO DE CLIENTE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            provider.isLoadingClientes
                ? _buildShimmerLoader()
                : _buildTipoClienteSection(provider),
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              metodoPagoField,
              const SizedBox(height: 16),
              clienteField,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: metodoPagoField),
            const SizedBox(width: 16),
            Expanded(child: clienteField),
          ],
        );
      },
    );
  }

  Widget _buildMetodoPagoDropdown(FacturaProvider provider) {
    final opciones =
        provider.metodosPagoCargados && provider.metodosPago.isNotEmpty
        ? provider.metodosPago.map((m) => m.name).toList()
        : ['Efectivo', 'Tarjeta', 'Transferencia'];

    // Asegurar que el valor seleccionado existe en las opciones
    String? valorActual =
        provider.metodoPago.isNotEmpty && opciones.contains(provider.metodoPago)
        ? provider.metodoPago
        : null;

    return DropdownButtonFormField<String>(
      key: ValueKey('metodo_pago_dropdown_${provider.formKey}'),
      value: valorActual,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.payment),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      hint: const Text('Seleccionar método'),
      items: opciones.map((String opcion) {
        return DropdownMenuItem<String>(value: opcion, child: Text(opcion));
      }).toList(),
      onChanged: (String? value) {
        if (value != null) {
          provider.setMetodoPago(value);
        }
      },
    );
  }

  Widget _buildTipoClienteSection(FacturaProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown de tipo de cliente
        DropdownButtonFormField<String>(
          value: _tipoCliente,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'general', child: Text('Cliente General')),
            DropdownMenuItem(
              value: 'especifico',
              child: Text('Cliente Específico'),
            ),
          ],
          onChanged: (String? value) {
            setState(() {
              _tipoCliente = value ?? 'general';
              _clienteSeleccionadoId = null;
              _mostrarDatosCliente = false;
              _nombreClienteController.clear();
              _telefonoClienteController.clear();
            });

            if (_tipoCliente == 'general') {
              // Buscar específicamente "Publico general"
              try {
                final clienteGeneral = provider.clientes.firstWhere(
                  (c) => c.nombreCliente.toLowerCase() == 'publico general',
                );
                provider.setCliente(
                  clienteGeneral.nombreCliente,
                  clienteId: clienteGeneral.idCliente,
                );
              } catch (_) {
                // Si no existe, dejar vacío
                provider.setCliente('');
              }
            } else {
              provider.setCliente('');
            }
          },
        ),

        // Mostrar opciones adicionales si es cliente específico
        if (_tipoCliente == 'especifico') ...[
          const SizedBox(height: 12),
          _buildClienteEspecificoSection(provider),
        ],
      ],
    );
  }

  Widget _buildClienteEspecificoSection(FacturaProvider provider) {
    final clientesEspecificos = provider.clientes
        .where((c) => !c.nombreCliente.toLowerCase().contains('general'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de búsqueda con autocompletado
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            final nombres = clientesEspecificos
                .map((c) => c.nombreCliente)
                .toList();
            if (textEditingValue.text.isEmpty) {
              return nombres;
            }
            return nombres.where((String option) {
              return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },
          onSelected: (String selection) {
            final cliente = provider.clientes.firstWhere(
              (c) => c.nombreCliente == selection,
            );
            setState(() {
              _clienteSeleccionadoId = cliente.idCliente;
              _nombreClienteController.text = cliente.nombreCliente;
              _telefonoClienteController.text = cliente.numeroTelefono ?? '';
              _mostrarDatosCliente = true;
            });
            provider.setCliente(selection);
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_search),
                    hintText: 'Buscar cliente existente o escribir nuevo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: textEditingController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _clienteSeleccionadoId = null;
                                _mostrarDatosCliente = false;
                                _nombreClienteController.clear();
                                _telefonoClienteController.clear();
                              });
                              provider.setCliente('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    // Si escribe algo nuevo, preparar para crear cliente
                    if (value.isNotEmpty && _clienteSeleccionadoId == null) {
                      setState(() {
                        _nombreClienteController.text = value;
                        _mostrarDatosCliente = true;
                      });
                      // Guardar nombre del cliente nuevo en el provider
                      provider.setCliente(value);
                    }
                  },
                  onSubmitted: (String value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _nombreClienteController.text = value;
                        _mostrarDatosCliente = true;
                      });
                    }
                    onFieldSubmitted();
                  },
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<String> onSelected,
                Iterable<String> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 200,
                        maxWidth: 350,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          final cliente = clientesEspecificos.firstWhere(
                            (c) => c.nombreCliente == option,
                          );
                          return ListTile(
                            leading: const Icon(Icons.person, size: 20),
                            title: Text(option),
                            subtitle: cliente.numeroTelefono != null
                                ? Text(
                                    cliente.numeroTelefono!,
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            dense: true,
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        ),

        // Mostrar campos editables de nombre y teléfono
        if (_mostrarDatosCliente) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _clienteSeleccionadoId != null
                          ? Icons.edit
                          : Icons.person_add,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _clienteSeleccionadoId != null
                          ? 'Editar datos del cliente'
                          : 'Datos del nuevo cliente',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nombreClienteController,
                  decoration: InputDecoration(
                    labelText: 'Nombre *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    provider.setCliente(value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _telefonoClienteController,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) {
                    // Guardar teléfono del cliente nuevo en el provider
                    if (_clienteSeleccionadoId == null) {
                      provider.setDatosClienteNuevo(telefono: value);
                    }
                  },
                ),
                if (_clienteSeleccionadoId != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _actualizarCliente(provider),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Guardar cambios'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _actualizarCliente(FacturaProvider provider) async {
    final nombre = _nombreClienteController.text.trim();
    final telefono = _telefonoClienteController.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre del cliente es obligatorio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('cliente')
          .update({
            'nombre_cliente': nombre,
            'numero_telefono': telefono.isEmpty ? null : telefono,
          })
          .eq('id_cliente', _clienteSeleccionadoId!);

      await provider.cargarClientes(forzar: true);
      provider.setCliente(nombre);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente "$nombre" actualizado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar cliente: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método público para obtener datos del cliente (usado al guardar venta)
  Map<String, dynamic>? getClienteData() {
    if (_tipoCliente == 'general') {
      return null; // Usar cliente general existente
    }

    final nombre = _nombreClienteController.text.trim();
    if (nombre.isEmpty) return null;

    return {
      'id': _clienteSeleccionadoId, // null si es nuevo
      'nombre': nombre,
      'telefono': _telefonoClienteController.text.trim(),
    };
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
      ),
    );
  }
}
