import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/inventory.dart'; 

class ItemCard extends StatelessWidget {
  final InventoryItem item; 
  final Function(InventoryItem) onClick;

  const ItemCard({
    super.key,
    required this.item,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLowStock = item.quantity <= (item.maxQuantity * 0.20);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => onClick(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(isLowStock),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNameAndPrice(),
                    const SizedBox(height: 8),
                    _buildStockAndLocation(isLowStock),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameAndPrice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '₱${item.price.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'SKU: ${item.sku}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStockAndLocation(bool isLowStock) {
    

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.package, size: 12),
              const SizedBox(width: 4),
              Text(
                "${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)}${item.unit}",
                style: TextStyle(
                  fontSize: 12,
                  color: isLowStock ? Colors.red : Colors.grey.shade600,
                  fontWeight: isLowStock ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        
        // Row(
        //   children: [
        //     const Icon(LucideIcons.mapPin, size: 12, color: Colors.grey),
        //     const SizedBox(width: 4),
        //     Text(
        //       locationText, 
        //       style: const TextStyle(fontSize: 12, color: Colors.grey),
        //     ),
        //   ],
        // ),
      ],
    );
  }
  Widget _buildImage(bool isLowStock) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
        ),
        if (isLowStock)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: const Text(
                'LOW STOCK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}