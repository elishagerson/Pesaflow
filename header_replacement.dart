            // ── HEADER ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: StaggeredFadeSlide(
                index: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.appColors.bgColor.withValues(alpha: 0.85),
                            context.appColors.bgColor.withValues(alpha: 0.98),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                      ),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 8,
                        bottom: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Transactions',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Track your recent activity',
                                      style: context.ts(13, color: onSurface.withValues(alpha: 0.5)),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (activeAccount != null ||
                                        activeCategory != null ||
                                        searchQuery.isNotEmpty ||
                                        activeType != 'All' ||
                                        amountMin != null ||
                                        amountMax != null ||
                                        dateFrom != null ||
                                        dateTo != null)
                                      IconButton(
                                        icon: Icon(PesaFlowIcons.clearAll, color: theme.colorScheme.error, size: 20),
                                        tooltip: 'Clear Filters',
                                        onPressed: () {
                                          ref.read(transactionTypeFilterProvider.notifier).state = 'All';
                                          ref.read(transactionAccountFilterProvider.notifier).state = null;
                                          ref.read(transactionCategoryFilterProvider.notifier).state = null;
                                          ref.read(transactionSearchQueryProvider.notifier).state = '';
                                          ref.read(transactionAmountMinProvider.notifier).state = null;
                                          ref.read(transactionAmountMaxProvider.notifier).state = null;
                                          ref.read(transactionDateFromProvider.notifier).state = null;
                                          ref.read(transactionDateToProvider.notifier).state = null;
                                          _searchController.clear();
                                        },
                                      ),
                                    _FilterButton(
                                      isActive: activeAccount != null ||
                                          activeCategory != null ||
                                          amountMin != null ||
                                          amountMax != null ||
                                          dateFrom != null ||
                                          dateTo != null ||
                                          searchQuery.isNotEmpty ||
                                          activeType != 'All',
                                      activeCount: [
                                        if (activeType != 'All') 1,
                                        if (activeAccount != null) 1,
                                        if (activeCategory != null) 1,
                                        if (searchQuery.isNotEmpty) 1,
                                        if (amountMin != null || amountMax != null) 1,
                                        if (dateFrom != null || dateTo != null) 1,
                                      ].length,
                                      onPressed: () => showTransactionFilterSheet(context, ref),
                                    ),
                                    const SizedBox(width: kSpacing8),
                                    TactileSpringContainer(
                                      onTap: () {
                                        setState(() {
                                          _isSearchVisible = !_isSearchVisible;
                                          if (!_isSearchVisible) {
                                            _searchController.clear();
                                            ref.read(transactionSearchQueryProvider.notifier).state = '';
                                          }
                                        });
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _isSearchVisible ? theme.colorScheme.primary.withValues(alpha: 0.12) : onSurface.withValues(alpha: 0.04),
                                          border: Border.all(
                                            color: _isSearchVisible ? theme.colorScheme.primary : onSurface.withValues(alpha: 0.08),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Icon(
                                          PesaFlowIcons.search,
                                          size: 18,
                                          color: _isSearchVisible ? theme.colorScheme.primary : onSurface.withValues(alpha: 0.62),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.fastOutSlowIn,
                            child: _isSearchVisible || searchQuery.isNotEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      top: kSpacing16,
                                      left: kSpacing20,
                                      right: kSpacing20,
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      autofocus: _isSearchVisible,
                                      onChanged: (val) {
                                        _searchDebounce?.cancel();
                                        _searchDebounce = Timer(
                                          const Duration(milliseconds: 300),
                                          () {
                                            ref.read(transactionSearchQueryProvider.notifier).state = val.trim();
                                          },
                                        );
                                      },
                                      decoration: context.inputDecoration(
                                        hintText: 'Search transactions...',
                                        prefixIcon: const Icon(PesaFlowIcons.search, size: 20),
                                        suffixIcon: searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: Icon(PesaFlowIcons.clear, size: 16, color: onSurface.withValues(alpha: 0.54)),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  ref.read(transactionSearchQueryProvider.notifier).state = '';
                                                },
                                              )
                                            : null,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: kSpacing16),
                          SizedBox(
                            height: 38,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                              children: ['All', 'Income', 'Expense', 'Transfer']
                                  .map((type) {
                                    final isSelected = activeType == type;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing4,
                                      ),
                                      child: TactileSpringContainer(
                                        onTap: () {
                                          ref.read(transactionTypeFilterProvider.notifier).state = type;
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOutCubic,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(100),
                                            border: Border.all(
                                              color: isSelected
                                                  ? theme.colorScheme.primary
                                                  : onSurface.withValues(alpha: 0.1),
                                              width: 1.0,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            type,
                                            style: context.ts(13, color: isSelected ? theme.colorScheme.onPrimary : onSurface.withValues(alpha: 0.7), fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
