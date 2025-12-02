import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:abari/providers/factura_provider.dart';
import 'package:intl/intl.dart';

class InvoiceHeaderFields extends StatelessWidget {
  const InvoiceHeaderFields({super.key});

  Future<void> _seleccionarFecha(BuildContext context) async {
    final provider = context.read<FacturaProvider>();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      provider.setFecha(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FacturaProvider>(
      builder: (context, provider, child) {
        final formatoFecha = DateFormat('dd/MM/yyyy');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color.fromARGB(255, 255, 255, 255)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _HeaderFieldEditable(
                  label: 'FECHA',
                  value: formatoFecha.format(provider.fecha),
                  icon: Icons.calendar_today,
                  onTap: () => _seleccionarFecha(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderFieldDropdown(
                  label: 'MÉTODO DE PAGO',
                  value: provider.metodoPago,
                  icon: Icons.credit_card,
                  opciones: const ['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'],
                  onChanged: (valor) =>
                      provider.setMetodoPago(valor ?? 'EFECTIVO'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderFieldText(
                  label: 'CLIENTE',
                  value: provider.cliente,
                  icon: Icons.person,
                  onChanged: (valor) => provider.setCliente(valor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderField(
                  label: 'TOTAL',
                  value: 'C\$${provider.total.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Campo de solo lectura
class _HeaderField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeaderField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(icon, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

// Campo editable con clic
class _HeaderFieldEditable extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderFieldEditable({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          // color: Colors.blue[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Icon(icon, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Campo de texto editable
class _HeaderFieldText extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _HeaderFieldText({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: value)
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: value.length),
                    ),
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
              Icon(icon, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

// Campo dropdown
class _HeaderFieldDropdown extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  const _HeaderFieldDropdown({
    required this.label,
    required this.value,
    required this.icon,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: opciones.map((String opcion) {
                    return DropdownMenuItem<String>(
                      value: opcion,
                      child: Text(
                        opcion,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
              Icon(icon, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
