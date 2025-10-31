import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/ai_provider.dart';
import '../../../shared/models/automation_state.dart';
import '../providers/provider_status_provider.dart';

class ProviderSelector extends ConsumerWidget {
  final AIProvider? selectedProvider;
  final Function(AIProvider) onProviderSelected;

  const ProviderSelector({
    Key? key,
    required this.selectedProvider,
    required this.onProviderSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerStatuses = ref.watch(providerStatusProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _showProviderSelector(context, ref, providerStatuses),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedProvider != null) ...[
              Icon(
                _getProviderIcon(selectedProvider!),
                size: 16,
                color: Colors.deepPurpleAccent,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              selectedProvider?.displayName ?? 'Sélectionner un provider',
              style: TextStyle(
                color: selectedProvider != null ? Colors.white : Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _showProviderSelector(
    BuildContext context,
    WidgetRef ref,
    Map<AIProvider, ProviderStatus> providerStatuses,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProviderSelectorSheet(
        selectedProvider: selectedProvider,
        providerStatuses: providerStatuses,
        onProviderSelected: (provider) {
          Navigator.pop(context);
          onProviderSelected(provider);
        },
      ),
    );
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.aistudio:
        return Icons.auto_awesome;
      case AIProvider.qwen:
        return Icons.cloud;
      case AIProvider.zai:
        return Icons.flash_on;
      case AIProvider.kimi:
        return Icons.document_scanner;
    }
  }
}

class ProviderSelectorSheet extends StatelessWidget {
  final AIProvider? selectedProvider;
  final Map<AIProvider, ProviderStatus> providerStatuses;
  final Function(AIProvider) onProviderSelected;

  const ProviderSelectorSheet({
    Key? key,
    required this.selectedProvider,
    required this.providerStatuses,
    required this.onProviderSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Sélectionner un Provider',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Provider List
          ...AIProvider.values.map((provider) {
            final status = providerStatuses[provider] ?? ProviderStatus.unknown;
            final isSelected = selectedProvider == provider;
            final isReady = status == ProviderStatus.ready;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isReady ? () => onProviderSelected(provider) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.deepPurpleAccent.withOpacity(0.2)
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.deepPurpleAccent
                            : Colors.grey.shade600,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Provider Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurpleAccent
                                : Colors.grey.shade700,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getProviderIcon(provider),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Provider Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.displayName,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.deepPurpleAccent
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                provider.url,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Status Indicator
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStatusIndicator(status),
                            const SizedBox(height: 4),
                            if (!isReady)
                              Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.end,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Help Text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade600),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assurez-vous d\'être connecté aux services IA avant de les utiliser.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(ProviderStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case ProviderStatus.ready:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case ProviderStatus.login:
        icon = Icons.login;
        color = Colors.orange;
        break;
      case ProviderStatus.loading:
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        break;
      case ProviderStatus.error:
        icon = Icons.error;
        color = Colors.red;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 20);
  }

  String _getStatusText(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.ready:
        return 'Prêt';
      case ProviderStatus.login:
        return 'Connexion requise';
      case ProviderStatus.loading:
        return 'Vérification...';
      case ProviderStatus.error:
        return 'Erreur';
      default:
        return 'Inconnu';
    }
  }

  Color _getStatusColor(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.ready:
        return Colors.green;
      case ProviderStatus.login:
        return Colors.orange;
      case ProviderStatus.loading:
        return Colors.blue;
      case ProviderStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.aistudio:
        return Icons.auto_awesome;
      case AIProvider.qwen:
        return Icons.cloud;
      case AIProvider.zai:
        return Icons.flash_on;
      case AIProvider.kimi:
        return Icons.document_scanner;
    }
  }
}