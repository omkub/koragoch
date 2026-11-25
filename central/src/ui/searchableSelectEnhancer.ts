/**
 * Global Searchable Dropdown Enhancer (Select2-style)
 *
 * เปลี่ยน <select> ทุกตัวในระบบให้กลายเป็น Dropdown ที่พิมพ์ค้นหาด้านในได้ทันทีตามรูปต้นแบบ
 * โดยยังทำงานร่วมกับ React 18 (value / onChange / disabled / dynamic <option> / <optgroup>) ได้ 100%
 */

interface OptionEntry {
  value: string;
  label: string;
  disabled: boolean;
  groupLabel: string | null;
}

let installed = false;

export function installSearchableSelectEnhancer() {
  if (installed || typeof window === 'undefined' || typeof document === 'undefined') {
    return;
  }
  installed = true;

  let activeSelect: HTMLSelectElement | null = null;
  let popoverEl: HTMLDivElement | null = null;
  let searchInputEl: HTMLInputElement | null = null;
  let listContainerEl: HTMLDivElement | null = null;
  let currentEntries: OptionEntry[] = [];
  let filteredEntries: OptionEntry[] = [];
  let highlightedIndex = -1;

  function extractOptions(selectEl: HTMLSelectElement): OptionEntry[] {
    const entries: OptionEntry[] = [];
    const children = Array.from(selectEl.children);

    for (const child of children) {
      if (child.tagName === 'OPTGROUP') {
        const group = child as HTMLOptGroupElement;
        const groupLabel = group.label || '';
        for (const opt of Array.from(group.children)) {
          if (opt.tagName === 'OPTION') {
            const o = opt as HTMLOptionElement;
            entries.push({
              value: o.value,
              label: (o.textContent ?? o.label ?? '').trim(),
              disabled: o.disabled || group.disabled,
              groupLabel,
            });
          }
        }
      } else if (child.tagName === 'OPTION') {
        const o = child as HTMLOptionElement;
        entries.push({
          value: o.value,
          label: (o.textContent ?? o.label ?? '').trim(),
          disabled: o.disabled,
          groupLabel: null,
        });
      }
    }
    return entries;
  }

  function setReactSelectValue(selectEl: HTMLSelectElement, nextValue: string) {
    if (selectEl.value === nextValue) return;
    const nativeSetter = Object.getOwnPropertyDescriptor(
      window.HTMLSelectElement.prototype,
      'value',
    )?.set;
    if (nativeSetter) {
      nativeSetter.call(selectEl, nextValue);
    } else {
      selectEl.value = nextValue;
    }
    selectEl.dispatchEvent(new Event('input', { bubbles: true }));
    selectEl.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function closePopover() {
    if (activeSelect) {
      activeSelect.removeAttribute('data-searchable-open');
    }
    activeSelect = null;
    if (popoverEl && popoverEl.parentNode) {
      popoverEl.parentNode.removeChild(popoverEl);
    }
    popoverEl = null;
    searchInputEl = null;
    listContainerEl = null;
    currentEntries = [];
    filteredEntries = [];
    highlightedIndex = -1;
  }

  function renderOptionList() {
    if (!listContainerEl || !activeSelect) return;
    listContainerEl.innerHTML = '';

    if (filteredEntries.length === 0) {
      const emptyEl = document.createElement('div');
      emptyEl.className = 'px-3 py-2.5 text-xs text-slate-400 text-center';
      emptyEl.textContent = 'ไม่พบตัวเลือกที่ค้นหา';
      listContainerEl.appendChild(emptyEl);
      return;
    }

    let lastGroup: string | null = null;

    filteredEntries.forEach((entry, idx) => {
      if (entry.groupLabel && entry.groupLabel !== lastGroup) {
        lastGroup = entry.groupLabel;
        const groupHeader = document.createElement('div');
        groupHeader.className =
          'px-3 py-1.5 text-[11px] font-bold text-slate-500 bg-slate-50 border-t border-slate-100 first:border-t-0 select-none';
        groupHeader.textContent = entry.groupLabel;
        listContainerEl!.appendChild(groupHeader);
      }

      const itemEl = document.createElement('div');
      const isHighlighted = idx === highlightedIndex;
      const isSelected = activeSelect!.value === entry.value;

      itemEl.setAttribute('role', 'option');
      itemEl.setAttribute('data-opt-idx', String(idx));
      itemEl.className = [
        'px-3 py-2 text-[13px] cursor-pointer transition-colors select-none break-words',
        entry.disabled ? 'opacity-40 cursor-not-allowed' : '',
        isHighlighted
          ? 'bg-[#005a9e] text-white font-medium'
          : isSelected
            ? 'bg-sky-50 text-[#005a9e] font-semibold'
            : 'text-slate-800 hover:bg-[#005a9e] hover:text-white',
      ]
        .filter(Boolean)
        .join(' ');
      itemEl.textContent = entry.label || '\u00A0';

      itemEl.addEventListener('mouseenter', () => {
        if (entry.disabled) return;
        highlightedIndex = idx;
      });

      itemEl.addEventListener('mousedown', (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (entry.disabled || !activeSelect) return;
        const target = activeSelect;
        setReactSelectValue(target, entry.value);
        closePopover();
      });

      listContainerEl!.appendChild(itemEl);
    });

    // เลื่อนให้ตัวที่ไฮไลต์อยู่ในสายตา
    if (highlightedIndex >= 0) {
      const activeItem = listContainerEl.querySelector(
        `[data-opt-idx="${highlightedIndex}"]`,
      ) as HTMLElement | null;
      if (activeItem) {
        activeItem.scrollIntoView({ block: 'nearest' });
      }
    }
  }

  function applyFilter(query: string) {
    const q = query.trim().toLowerCase();
    filteredEntries = !q
      ? currentEntries
      : currentEntries.filter(
          (e) =>
            e.label.toLowerCase().includes(q) ||
            (e.groupLabel && e.groupLabel.toLowerCase().includes(q)),
        );

    if (activeSelect) {
      const selectedIdx = filteredEntries.findIndex(
        (e) => e.value === activeSelect!.value && !e.disabled,
      );
      highlightedIndex =
        selectedIdx >= 0
          ? selectedIdx
          : filteredEntries.findIndex((e) => !e.disabled);
    } else {
      highlightedIndex = 0;
    }

    renderOptionList();
  }

  function positionPopover() {
    if (!activeSelect || !popoverEl) return;
    const rect = activeSelect.getBoundingClientRect();
    const viewportW = window.innerWidth;
    const viewportH = window.innerHeight;

    const width = Math.min(Math.max(rect.width, 220), viewportW - 16);
    let left = rect.left;
    if (left + width > viewportW - 8) {
      left = Math.max(8, viewportW - width - 8);
    }

    popoverEl.style.width = `${width}px`;
    popoverEl.style.left = `${left}px`;

    // ตรวจว่าพื้นที่ด้านล่างพอไหม ถ้าไม่พอให้เปิดขึ้นด้านบน
    const estimatedHeight = Math.min(310, 56 + currentEntries.length * 36);
    const spaceBelow = viewportH - rect.bottom - 8;
    const spaceAbove = rect.top - 8;

    if (spaceBelow < estimatedHeight && spaceAbove > spaceBelow) {
      popoverEl.style.top = 'auto';
      popoverEl.style.bottom = `${viewportH - rect.top + 2}px`;
    } else {
      popoverEl.style.bottom = 'auto';
      popoverEl.style.top = `${rect.bottom + 2}px`;
    }
  }

  function openPopoverForSelect(selectEl: HTMLSelectElement) {
    if (activeSelect === selectEl) {
      closePopover();
      return;
    }
    closePopover();

    activeSelect = selectEl;
    activeSelect.setAttribute('data-searchable-open', 'true');
    currentEntries = extractOptions(selectEl);

    const pop = document.createElement('div');
    pop.setAttribute('data-searchable-popover', 'true');
    pop.className =
      'fixed z-[99999] rounded-xl border border-slate-300 bg-white shadow-[0_10px_28px_rgba(15,23,42,0.18)] overflow-hidden flex flex-col print:hidden';
    pop.style.maxHeight = '320px';

    // ช่องค้นหาด้านบนใน Dropdown (ตามรูปต้นแบบ)
    const searchWrap = document.createElement('div');
    searchWrap.className = 'p-2 bg-white border-b border-slate-100';

    const input = document.createElement('input');
    input.type = 'text';
    input.placeholder = 'พิมพ์เพื่อค้นหา...';
    input.autocomplete = 'off';
    input.className =
      'w-full rounded-lg border-2 border-sky-400 bg-white px-2.5 py-1.5 text-[13px] text-slate-900 placeholder:text-slate-400 focus:border-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-200';

    input.addEventListener('input', () => {
      applyFilter(input.value);
    });

    input.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (filteredEntries.length === 0) return;
        highlightedIndex = (highlightedIndex + 1) % filteredEntries.length;
        renderOptionList();
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (filteredEntries.length === 0) return;
        highlightedIndex =
          (highlightedIndex - 1 + filteredEntries.length) %
          filteredEntries.length;
        renderOptionList();
      } else if (e.key === 'Enter') {
        e.preventDefault();
        const chosen = filteredEntries[highlightedIndex];
        if (chosen && !chosen.disabled && activeSelect) {
          setReactSelectValue(activeSelect, chosen.value);
          closePopover();
        }
      } else if (e.key === 'Escape' || e.key === 'Tab') {
        closePopover();
      }
    });

    searchWrap.appendChild(input);

    const listEl = document.createElement('div');
    listEl.className = 'overflow-y-auto max-h-[248px] divide-y divide-slate-50';

    pop.appendChild(searchWrap);
    pop.appendChild(listEl);
    document.body.appendChild(pop);

    popoverEl = pop;
    searchInputEl = input;
    listContainerEl = listEl;

    applyFilter('');
    positionPopover();

    requestAnimationFrame(() => {
      searchInputEl?.focus();
    });
  }

  // ดักคลิกบน <select> ทุกตัวในหน้า
  document.addEventListener(
    'mousedown',
    (e) => {
      const target = e.target as HTMLElement | null;
      if (!target) return;

      // หากคลิกอยู่ใน popover ของเราเอง ปล่อยทำงานตามปกติ
      if (popoverEl && popoverEl.contains(target)) {
        return;
      }

      const selectEl = target.closest('select') as HTMLSelectElement | null;
      if (
        selectEl &&
        !selectEl.disabled &&
        !selectEl.multiple &&
        selectEl.size <= 1 &&
        selectEl.getAttribute('data-native-select') !== 'true'
      ) {
        e.preventDefault();
        openPopoverForSelect(selectEl);
        return;
      }

      // คลิกนอก popover → ปิด
      if (popoverEl) {
        closePopover();
      }
    },
    true,
  );

  // รองรับการกด Space / Enter / ArrowDown เวลาโฟกัสอยู่ที่ <select>
  document.addEventListener(
    'keydown',
    (e) => {
      const target = e.target as HTMLElement | null;
      if (!target || target.tagName !== 'SELECT') return;
      const selectEl = target as HTMLSelectElement;
      if (
        selectEl.disabled ||
        selectEl.multiple ||
        selectEl.getAttribute('data-native-select') === 'true'
      ) {
        return;
      }
      if (e.key === ' ' || e.key === 'Enter' || e.key === 'ArrowDown') {
        e.preventDefault();
        openPopoverForSelect(selectEl);
      }
    },
    true,
  );

  window.addEventListener(
    'scroll',
    (e) => {
      if (!popoverEl) return;
      if (listContainerEl && e.target === listContainerEl) return;
      positionPopover();
    },
    true,
  );

  window.addEventListener('resize', () => {
    if (popoverEl) positionPopover();
  });
}
