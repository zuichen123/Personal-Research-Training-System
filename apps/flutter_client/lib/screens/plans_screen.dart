import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plan.dart';
import '../providers/app_provider.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final plans = provider.plans;
    final loading = provider.isSectionLoading(DataSection.plans);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchPlans(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchPlans(force: true),
        child: _buildBody(provider, plans, loading),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add_task),
        label: const Text('New Plan'),
      ),
    );
  }

  Widget _buildBody(AppProvider provider, List<PlanItem> plans, bool loading) {
    if (loading && plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && plans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('Load failed: ${provider.errorMessage}')),
        ],
      );
    }

    if (plans.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 96),
          Center(child: Text('No plans yet.')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final item = plans[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(item.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${item.planType} | Status: ${item.status}'),
                if (item.targetDate.isNotEmpty)
                  Text('Target: ${item.targetDate}'),
                Text('Priority: ${item.priority}'),
                if (item.content.isNotEmpty)
                  Text(
                    item.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final targetController = TextEditingController();
    String selectedType = 'day_plan';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Create Plan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Plan Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'month_goal',
                          child: Text('Month Goal'),
                        ),
                        DropdownMenuItem(
                          value: 'month_plan',
                          child: Text('Month Plan'),
                        ),
                        DropdownMenuItem(
                          value: 'day_goal',
                          child: Text('Day Goal'),
                        ),
                        DropdownMenuItem(
                          value: 'day_plan',
                          child: Text('Day Plan'),
                        ),
                        DropdownMenuItem(
                          value: 'current_phase',
                          child: Text('Current Phase'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(labelText: 'Content'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      decoration: const InputDecoration(
                        labelText: 'Target Date',
                        hintText: 'YYYY-MM-DD (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Title is required.')),
                      );
                      return;
                    }

                    try {
                      await provider.createPlan({
                        'plan_type': selectedType,
                        'title': titleController.text.trim(),
                        'content': contentController.text.trim(),
                        'target_date': targetController.text.trim(),
                        'status': 'pending',
                        'priority': 3,
                      });
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Create failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
    targetController.dispose();
  }
}
