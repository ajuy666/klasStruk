import 'package:flutter/material.dart';
import '../models/receipt_item.dart';

class EditableReceiptTable extends StatefulWidget {
  final List<ReceiptItem> initialItems;
  final int total;
  final Color accentColor;
  final ValueChanged<List<ReceiptItem>>? onItemsChanged;

  const EditableReceiptTable({
    super.key,
    required this.initialItems,
    required this.total,
    this.accentColor = const Color(0xFF6F52C8),
    this.onItemsChanged,
  });

  @override
  State<EditableReceiptTable> createState() => _EditableReceiptTableState();
}

class _EditableReceiptTableState extends State<EditableReceiptTable> {
  // Kategori yang dapat dipilih pengguna apabila hasil prediksi LSTM perlu diperbaiki.
  static const List<String> _categoryOptions = [
    'bahan_pokok',
    'kebutuhan_rumah_tangga',
    'makanan',
    'minuman',
    'lainnya',
  ];

  late List<ReceiptItem> items;

  @override
  void initState() {
    super.initState();
    items = widget.initialItems.map((e) {
      return ReceiptItem(
        name: e.name,
        qty: e.qty,
        unit: e.unit,
        price: e.price,
        amount: e.amount,
        status: e.status,
        category: e.category,
        predictionConfidence: e.predictionConfidence,
      );
    }).toList();
  }

  void _notifyItemsChanged() {
    widget.onItemsChanged?.call(
      items
          .map(
            (item) => ReceiptItem(
              name: item.name,
              qty: item.qty,
              unit: item.unit,
              price: item.price,
              amount: item.amount,
              status: item.status,
              category: item.category,
              predictionConfidence: item.predictionConfidence,
            ),
          )
          .toList(),
    );
  }

  int _toInt(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  String _formatCurrency(num value) {
    final raw = value.toStringAsFixed(0);
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  int _rowTotal(ReceiptItem item) {
    final qty = _toInt(item.qty);
    final price = _toInt(item.price);
    final amount = _toInt(item.amount);

    if (amount > 0) return amount;
    return qty * price;
  }

  int _subtotal() {
    int sum = 0;
    for (final item in items) {
      sum += _rowTotal(item);
    }
    return sum;
  }

  void _addRow() {
    setState(() {
      items.add(
        ReceiptItem(
          name: '',
          qty: '1',
          unit: '',
          price: '',
          amount: '',
          status: 'ditambah user',
          category: 'lainnya',
        ),
      );
    });
    _notifyItemsChanged();
  }

  void _removeRow(int index) {
    setState(() {
      items.removeAt(index);
    });
    _notifyItemsChanged();
  }

  Widget _headerCell(
    String text, {
    double? width,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: width,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _bodyCell(
    Widget child, {
    double? width,
    Alignment alignment = Alignment.centerLeft,
    bool removeRightBorder = false,
  }) {
    return Container(
      width: width,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: removeRightBorder
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE8EAF2)),
          bottom: const BorderSide(color: Color(0xFFE8EAF2)),
        ),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: widget.accentColor, width: 1.4),
      ),
    );
  }

  Color _categoryBg(String? category) {
    final value = (category ?? '').toLowerCase().trim();

    switch (value) {
      case 'makanan':
        return const Color(0xFFFFF1F2);
      case 'minuman':
        return const Color(0xFFEFF6FF);
      case 'bahan_pokok':
      case 'bahan pokok':
        return const Color(0xFFF0FDF4);
      case 'kebutuhan_rumah_tangga':
      case 'kebutuhan rumah tangga':
        return const Color(0xFFF5F3FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _categoryText(String? category) {
    final value = (category ?? '').toLowerCase().trim();

    switch (value) {
      case 'makanan':
        return const Color(0xFFBE123C);
      case 'minuman':
        return const Color(0xFF1D4ED8);
      case 'bahan_pokok':
      case 'bahan pokok':
        return const Color(0xFF15803D);
      case 'kebutuhan_rumah_tangga':
      case 'kebutuhan rumah tangga':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF334155);
    }
  }

  String _prettyCategory(String? category) {
    final value = (category ?? '').trim();
    if (value.isEmpty) return 'lainnya';

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _selectableCategory(String? category) {
    final value = (category ?? '').trim().toLowerCase().replaceAll(' ', '_');
    return _categoryOptions.contains(value) ? value : 'lainnya';
  }

  @override
  Widget build(BuildContext context) {
    const noWidth = 54.0;
    const nameWidth = 230.0;
    const qtyWidth = 80.0;
    const priceWidth = 130.0;
    const totalWidth = 130.0;
    const categoryWidth = 150.0;
    const actionWidth = 70.0;

    final subtotal = _subtotal() > 0 ? _subtotal() : widget.total;
    final tableWidth =
        noWidth +
        nameWidth +
        qtyWidth +
        priceWidth +
        totalWidth +
        categoryWidth +
        actionWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Detail Item',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF152238),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _addRow,
              icon: Icon(Icons.add, size: 18, color: widget.accentColor),
              label: Text(
                'Tambah',
                style: TextStyle(
                  color: widget.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EAF2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    Container(
                      color: widget.accentColor,
                      child: Row(
                        children: [
                          _headerCell('No', width: noWidth),
                          _headerCell(
                            'Nama Barang',
                            width: nameWidth,
                            alignment: Alignment.centerLeft,
                          ),
                          _headerCell('Qty', width: qtyWidth),
                          _headerCell('Harga', width: priceWidth),
                          _headerCell('Total', width: totalWidth),
                          _headerCell('Kategori', width: categoryWidth),
                          _headerCell('Aksi', width: actionWidth),
                        ],
                      ),
                    ),
                    if (items.isEmpty)
                      Container(
                        width: tableWidth,
                        padding: const EdgeInsets.all(18),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE8EAF2)),
                          ),
                        ),
                        child: const Text(
                          'Belum ada item',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ...List.generate(items.length, (index) {
                      final item = items[index];
                      final total = _rowTotal(item);
                      final hasDetectedPrice =
                          _toInt(item.price) > 0 || _toInt(item.amount) > 0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bodyCell(
                            Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF152238),
                              ),
                            ),
                            width: noWidth,
                            alignment: Alignment.center,
                          ),
                          _bodyCell(
                            TextFormField(
                              initialValue: item.name,
                              decoration: _inputDecoration(hint: 'Nama barang'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF152238),
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  item.name = value;
                                  if (item.status == 'hasil OCR' ||
                                      item.status == 'perlu cek') {
                                    item.status = 'diubah user';
                                  }
                                });
                                _notifyItemsChanged();
                              },
                            ),
                            width: nameWidth,
                          ),
                          _bodyCell(
                            TextFormField(
                              initialValue: item.qty ?? '',
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: _inputDecoration(hint: '0'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF152238),
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  item.qty = value;
                                  item.amount =
                                      (_toInt(item.qty) * _toInt(item.price))
                                          .toString();
                                  if (item.status == 'hasil OCR' ||
                                      item.status == 'perlu cek') {
                                    item.status = 'diubah user';
                                  }
                                });
                                _notifyItemsChanged();
                              },
                            ),
                            width: qtyWidth,
                            alignment: Alignment.center,
                          ),
                          _bodyCell(
                            TextFormField(
                              initialValue: item.price ?? '',
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: _inputDecoration(hint: '0'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF152238),
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  item.price = value;
                                  item.amount =
                                      (_toInt(item.qty) * _toInt(item.price))
                                          .toString();
                                  if (item.status == 'hasil OCR' ||
                                      item.status == 'perlu cek') {
                                    item.status = 'diubah user';
                                  }
                                });
                                _notifyItemsChanged();
                              },
                            ),
                            width: priceWidth,
                            alignment: Alignment.center,
                          ),
                          _bodyCell(
                            Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                hasDetectedPrice
                                    ? _formatCurrency(total)
                                    : '-',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF152238),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            width: totalWidth,
                            alignment: Alignment.center,
                          ),
                          _bodyCell(
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: _categoryBg(item.category),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectableCategory(item.category),
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: _categoryText(item.category),
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _categoryText(item.category),
                                  ),
                                  items: _categoryOptions
                                      .map(
                                        (category) => DropdownMenuItem<String>(
                                          value: category,
                                          child: Text(
                                            _prettyCategory(category),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (category) {
                                    if (category == null ||
                                        category == item.category) {
                                      return;
                                    }

                                    setState(() {
                                      // Pilihan pengguna menjadi kategori akhir yang disimpan.
                                      item.category = category;
                                      item.status = 'kategori diubah user';
                                      // Confidence ini hanya milik prediksi LSTM awal.
                                      item.predictionConfidence = null;
                                    });
                                    _notifyItemsChanged();
                                  },
                                ),
                              ),
                            ),
                            width: categoryWidth,
                            alignment: Alignment.center,
                          ),
                          _bodyCell(
                            IconButton(
                              onPressed: () => _removeRow(index),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                            ),
                            width: actionWidth,
                            alignment: Alignment.center,
                            removeRightBorder: true,
                          ),
                        ],
                      );
                    }),
                    Container(
                      width: tableWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      color: widget.accentColor.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          const Spacer(),
                          Text(
                            'SUB TOTAL',
                            style: TextStyle(
                              color: widget.accentColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Text(
                            _formatCurrency(subtotal),
                            style: TextStyle(
                              color: widget.accentColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
