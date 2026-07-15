import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../../core/domain/value_objects/media_asset.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../feed/domain/entities/upload_status.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../application/marketplace_catalog.dart';
import '../../application/marketplace_providers.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/marketplace_requests.dart';

class CreateMarketplaceListingScreen extends ConsumerStatefulWidget {
  const CreateMarketplaceListingScreen({this.listingId, super.key});

  final String? listingId;

  @override
  ConsumerState<CreateMarketplaceListingScreen> createState() =>
      _CreateMarketplaceListingScreenState();
}

class _CreateMarketplaceListingScreenState
    extends ConsumerState<CreateMarketplaceListingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final List<String> _localImages = <String>[];
  List<MediaAsset> _existingMedia = <MediaAsset>[];
  String _sportId = 'football';
  String _categoryId = 'football_gear';
  ListingCondition _condition = ListingCondition.good;
  Set<MarketplaceDeliveryOption> _delivery = <MarketplaceDeliveryOption>{
    MarketplaceDeliveryOption.meetup,
  };
  bool _negotiable = false;
  bool _submitting = false;
  bool _hydrated = false;
  bool _draftCreated = false;
  String? _workingListingId;
  double _progress = 0;

  bool get _editing => widget.listingId != null;

  @override
  void initState() {
    super.initState();
    _workingListingId = widget.listingId;
    _draftCreated = widget.listingId != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      final AsyncValue<MarketplaceListing?> listingValue = ref.watch(
        marketplaceListingProvider(widget.listingId!),
      );
      if (!_hydrated && listingValue.value != null) {
        _hydrated = true;
        unawaited(Future<void>.microtask(() => _hydrate(listingValue.value!)));
      }
      if (listingValue.isLoading && !_hydrated) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }
    final UserProfile? profile = ref.watch(currentUserProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit listing' : 'Sell equipment')),
      body: Form(
        key: _formKey,
        child: AdaptivePageBody(
          maxWidth: 820,
          slivers: <Widget>[
            AppPageHeader(
              eyebrow: 'ReeMove Marketplace',
              title: _editing
                  ? 'Update your listing'
                  : 'Create a trusted listing',
              subtitle:
                  'Add clear photos and an honest condition. Only an approximate pickup area is shown publicly.',
            ),
            const SizedBox(height: AppSpacing.xl),
            _PhotoPicker(
              existing: _existingMedia,
              localPaths: _localImages,
              onPick: _pickImages,
              onRemoveExisting: _removeExisting,
              onRemoveLocal: (String path) =>
                  setState(() => _localImages.remove(path)),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _titleController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Example: Adjustable dumbbells 20 kg',
              ),
              validator: (String? value) {
                final int length = value?.trim().length ?? 0;
                return length < 4 ? 'Enter a clear title.' : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText:
                    'Condition, size, age, included parts, and any defects.',
                alignLabelWithHint: true,
              ),
              validator: (String? value) {
                final int length = value?.trim().length ?? 0;
                return length < 12 ? 'Add more useful details.' : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sportId,
                    decoration: const InputDecoration(labelText: 'Sport'),
                    items: MarketplaceCatalog.sportLabels.entries
                        .map(
                          (MapEntry<String, String> entry) =>
                              DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _sportId = value;
                        final List<MarketplaceCategoryOption> supported =
                            _supportedCategories(value);
                        if (!supported.any((item) => item.id == _categoryId)) {
                          _categoryId = supported.first.id;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>('category-$_sportId-$_categoryId'),
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _supportedCategories(_sportId)
                        .map(
                          (MarketplaceCategoryOption item) =>
                              DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.label),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => _categoryId = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ListingCondition>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: ListingCondition.values
                  .map(
                    (ListingCondition item) =>
                        DropdownMenuItem<ListingCondition>(
                          value: item,
                          child: Text(_conditionLabel(item)),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (ListingCondition? value) {
                if (value != null) {
                  setState(() => _condition = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '₪ ',
                    ),
                    validator: (String? value) {
                      final double? parsed = double.tryParse(
                        value?.trim() ?? '',
                      );
                      return parsed == null || parsed < 0
                          ? 'Enter a valid price.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Negotiable'),
                    value: _negotiable,
                    onChanged: (bool value) =>
                        setState(() => _negotiable = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Delivery options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: MarketplaceDeliveryOption.values
                  .map(
                    (MarketplaceDeliveryOption item) => FilterChip(
                      label: Text(_deliveryLabel(item)),
                      selected: _delivery.contains(item),
                      onSelected: (bool selected) {
                        final Set<MarketplaceDeliveryOption> next =
                            Set<MarketplaceDeliveryOption>.from(_delivery);
                        selected ? next.add(item) : next.remove(item);
                        if (next.isNotEmpty) {
                          setState(() => _delivery = next);
                        }
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                  profile?.location?.locality ?? 'Pickup area required',
                ),
                subtitle: const Text(
                  'ReeMove rounds the saved coordinates before publishing. Your exact location is never placed in the listing.',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Marketplace safety'),
                subtitle: const Text(
                  'Weapons, alcohol, nicotine, drugs, restricted medication, supplements, counterfeit goods, and stolen items are prohibited.',
                ),
              ),
            ),
            if (_submitting) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _progress > 0 && _progress < 1
                    ? 'Uploading photos… ${(_progress * 100).round()}%'
                    : 'Saving and verifying listing…',
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _submitting ? null : () => _submit(profile),
              icon: const Icon(Icons.publish_rounded),
              label: Text(_editing ? 'Save and publish' : 'Publish listing'),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _hydrate(MarketplaceListing listing) {
    if (!mounted) {
      return;
    }
    setState(() {
      _titleController.text = listing.title;
      _descriptionController.text = listing.description;
      _priceController.text = listing.price.amountMajor.toStringAsFixed(
        listing.price.amountMajor % 1 == 0 ? 0 : 2,
      );
      _sportId = listing.sportId;
      _categoryId = listing.categoryId;
      _condition = listing.condition;
      _delivery = listing.deliveryOptions.toSet();
      _negotiable = listing.isNegotiable;
      _existingMedia = List<MediaAsset>.from(listing.media);
    });
  }

  Future<void> _pickImages() async {
    final int remaining = 8 - _existingMedia.length - _localImages.length;
    if (remaining <= 0) {
      return;
    }
    final List<String> paths = await ref
        .read(marketplaceMediaPickerProvider)
        .pickImages(limit: remaining);
    if (mounted) {
      setState(() => _localImages.addAll(paths));
    }
  }

  Future<void> _removeExisting(MediaAsset asset) async {
    // Keep the object in Storage until the server accepts the edited draft.
    // This prevents a cancelled edit from leaving the published document with
    // a broken image reference. Orphan cleanup is handled asynchronously.
    if (mounted) {
      setState(
        () => _existingMedia.removeWhere(
          (MediaAsset item) => item.id == asset.id,
        ),
      );
    }
  }

  Future<void> _submit(UserProfile? profile) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (profile?.location == null) {
      _snack('Add a location in profile privacy and discovery settings first.');
      return;
    }
    if (_existingMedia.isEmpty && _localImages.isEmpty) {
      _snack('Add at least one clear photo.');
      return;
    }
    setState(() {
      _submitting = true;
      _progress = 0;
    });
    final String listingId = _workingListingId ??=
        widget.listingId ?? 'mkt_${DateTime.now().microsecondsSinceEpoch}';
    final GeoLocation location = profile!.location!;
    MarketplaceListingDraft draft = _draft(
      listingId: listingId,
      location: location,
      media: _existingMedia,
    );
    if (!_draftCreated) {
      final Result<String> created = await ref
          .read(marketplaceActionControllerProvider.notifier)
          .createDraft(draft);
      final bool ok = created.when<bool>(
        success: (String createdId) {
          _workingListingId = createdId;
          _draftCreated = true;
          return true;
        },
        failure: (Failure failure) {
          _snack(failure.message);
          return false;
        },
      );
      if (!ok) {
        _finish();
        return;
      }
    }

    final List<String> pendingPaths = List<String>.from(_localImages);
    for (int index = 0; index < pendingPaths.length; index += 1) {
      final String localPath = pendingPaths[index];
      final String assetId =
          'asset_${DateTime.now().microsecondsSinceEpoch}_$index';
      MediaAsset? asset;
      await for (final MediaUploadStatus status
          in ref
              .read(marketplaceMediaRepositoryProvider)
              .uploadImage(
                listingId: listingId,
                localPath: localPath,
                assetId: assetId,
              )) {
        if (!mounted) {
          return;
        }
        setState(() {
          _progress = (index + status.progress) / pendingPaths.length;
        });
        if (status.state == MediaProcessingState.failed) {
          _snack(status.message ?? 'A photo could not be uploaded.');
          _finish();
          return;
        }
        asset = status.asset ?? asset;
      }
      if (asset != null && mounted) {
        setState(() {
          _existingMedia.add(asset!);
          _localImages.remove(localPath);
        });
        final bool checkpointSaved = await ref
            .read(marketplaceActionControllerProvider.notifier)
            .saveDraft(
              _draft(
                listingId: listingId,
                location: location,
                media: _existingMedia,
              ),
            );
        if (!checkpointSaved) {
          _snack(
            'The photo uploaded, but the draft checkpoint could not be saved. Try again from My listings.',
          );
          _finish();
          return;
        }
      }
    }
    draft = _draft(
      listingId: listingId,
      location: location,
      media: _existingMedia,
    );
    final bool saved = await ref
        .read(marketplaceActionControllerProvider.notifier)
        .saveDraft(draft);
    if (!saved) {
      _finish();
      return;
    }
    final bool published = await ref
        .read(marketplaceActionControllerProvider.notifier)
        .publish(listingId);
    if (!published) {
      _finish();
      return;
    }
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.marketplaceListing(listingId));
  }

  MarketplaceListingDraft _draft({
    required String listingId,
    required GeoLocation location,
    required List<MediaAsset> media,
  }) {
    final double amount = double.tryParse(_priceController.text.trim()) ?? 0;
    return MarketplaceListingDraft(
      id: listingId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryId: _categoryId,
      sportId: _sportId,
      condition: _condition,
      priceAmountMinor: (amount * 100).round(),
      currency: 'ILS',
      isNegotiable: _negotiable,
      deliveryOptions: _delivery,
      media: List<MediaAsset>.unmodifiable(media),
      location: location,
    );
  }

  void _finish() {
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static List<MarketplaceCategoryOption> _supportedCategories(String sportId) {
    return MarketplaceCatalog.categories
        .where(
          (MarketplaceCategoryOption item) =>
              item.sportIds.isEmpty || item.sportIds.contains(sportId),
        )
        .toList(growable: false);
  }

  static String _conditionLabel(ListingCondition value) => switch (value) {
    ListingCondition.newItem => 'New, unused',
    ListingCondition.likeNew => 'Like new',
    ListingCondition.good => 'Good',
    ListingCondition.fair => 'Fair',
    ListingCondition.poor => 'Well used',
  };

  static String _deliveryLabel(MarketplaceDeliveryOption value) =>
      switch (value) {
        MarketplaceDeliveryOption.pickup => 'Pickup area',
        MarketplaceDeliveryOption.meetup => 'Meet in public',
        MarketplaceDeliveryOption.shipping => 'Shipping',
      };
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.existing,
    required this.localPaths,
    required this.onPick,
    required this.onRemoveExisting,
    required this.onRemoveLocal,
  });

  final List<MediaAsset> existing;
  final List<String> localPaths;
  final VoidCallback onPick;
  final ValueChanged<MediaAsset> onRemoveExisting;
  final ValueChanged<String> onRemoveLocal;

  @override
  Widget build(BuildContext context) {
    final int count = existing.length + localPaths.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Photos ($count/8)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: count >= 8 ? null : onPick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add photos'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (count == 0)
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.add_photo_alternate_outlined, size: 44),
                    SizedBox(height: AppSpacing.sm),
                    Text('Add up to eight clear photos'),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                ...existing.map(
                  (MediaAsset asset) => _PhotoTile(
                    image: asset.downloadUrl == null
                        ? const ColoredBox(
                            color: Colors.black12,
                            child: Center(child: Icon(Icons.image_outlined)),
                          )
                        : Image.network(asset.downloadUrl!, fit: BoxFit.cover),
                    onRemove: () => onRemoveExisting(asset),
                  ),
                ),
                ...localPaths.map(
                  (String path) => _PhotoTile(
                    image: FutureBuilder<Uint8List>(
                      future: XFile(path).readAsBytes(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<Uint8List> snap,
                          ) {
                            if (!snap.hasData) {
                              return const ColoredBox(
                                color: Colors.black12,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return Image.memory(snap.data!, fit: BoxFit.cover);
                          },
                    ),
                    onRemove: () => onRemoveLocal(path),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.image, required this.onRemove});

  final Widget image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Stack(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(width: 150, height: 150, child: image),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton.filledTonal(
              tooltip: 'Remove photo',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
