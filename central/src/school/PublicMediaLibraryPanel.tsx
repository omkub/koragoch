import { useMemo, useState } from 'react';
import {
  Check,
  Copy,
  ExternalLink,
  FileText,
  FolderInput,
  Image as ImageIcon,
  LayoutGrid,
  List,
  Plus,
  Search,
  Trash2,
  Upload,
  X,
} from 'lucide-react';
import { logoSrc } from '../ui/SchoolLogo';
import { readOptionalFileDataUrl } from './publicWebAdmissions';
import type { PublicMediaItem } from './publicWebConfig';

interface PublicMediaLibraryPanelProps {
  items: PublicMediaItem[];
  onChange: (next: PublicMediaItem[]) => void;
}

const FOLDERS: PublicMediaItem['folder'][] = [
  'ข่าวประชาสัมพันธ์',
  'เอกสารรับสมัคร',
  'แบนเนอร์และกิจกรรม',
  'ทั่วไป',
];

export default function PublicMediaLibraryPanel({
  items,
  onChange,
}: PublicMediaLibraryPanelProps) {
  const [viewMode, setViewMode] = useState<'grid' | 'table'>('grid');
  const [folderFilter, setFolderFilter] = useState<'all' | PublicMediaItem['folder']>(
    'all',
  );
  const [typeFilter, setTypeFilter] = useState<'all' | 'image' | 'document'>(
    'all',
  );
  const [search, setSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [previewItem, setPreviewItem] = useState<PublicMediaItem | null>(null);

  // Add Media Modal
  const [addOpen, setAddOpen] = useState(false);
  const [newName, setNewName] = useState('');
  const [newType, setNewType] = useState<'image' | 'document'>('image');
  const [newFolder, setNewFolder] =
    useState<PublicMediaItem['folder']>('ข่าวประชาสัมพันธ์');
  const [newUrl, setNewUrl] = useState('');
  const [newSizeLabel, setNewSizeLabel] = useState('ลิงก์ภายนอก');
  const [uploadError, setUploadError] = useState<string | null>(null);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((it) => {
      if (folderFilter !== 'all' && it.folder !== folderFilter) return false;
      if (typeFilter !== 'all' && it.type !== typeFilter) return false;
      if (!q) return true;
      return (
        it.name.toLowerCase().includes(q) ||
        it.folder.toLowerCase().includes(q) ||
        it.url.toLowerCase().includes(q)
      );
    });
  }, [items, folderFilter, typeFilter, search]);

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleCopyUrl = async (item: PublicMediaItem) => {
    try {
      await navigator.clipboard.writeText(item.url);
      setCopiedId(item.id);
      setTimeout(() => setCopiedId(null), 1800);
    } catch {
      window.prompt('คัดลอกลิงก์สื่อ:', item.url);
    }
  };

  const handleBulkDelete = () => {
    if (selectedIds.size === 0) return;
    if (
      !window.confirm(
        `ต้องการลบสื่อและเอกสารที่เลือกจำนวน ${selectedIds.size} รายการหรือไม่?`,
      )
    ) {
      return;
    }
    onChange(items.filter((it) => !selectedIds.has(it.id)));
    setSelectedIds(new Set());
  };

  const handleBulkMoveFolder = (targetFolder: PublicMediaItem['folder']) => {
    if (selectedIds.size === 0) return;
    onChange(
      items.map((it) =>
        selectedIds.has(it.id) ? { ...it, folder: targetFolder } : it,
      ),
    );
    setSelectedIds(new Set());
  };

  const handleLocalFilePick = async (file: File | null) => {
    setUploadError(null);
    if (!file) return;
    if (!newName.trim()) setNewName(file.name);
    const isImg = file.type.startsWith('image/');
    setNewType(isImg ? 'image' : 'document');
    const kb = Math.max(1, Math.round(file.size / 1024));
    setNewSizeLabel(kb >= 1024 ? `${(kb / 1024).toFixed(1)} MB` : `${kb} KB`);
    const dataUrl = await readOptionalFileDataUrl(file, 450_000);
    if (!dataUrl) {
      setUploadError(
        'ไฟล์มีขนาดเกิน 450 KB กรุณาอัปโหลดขึ้น Google Drive แล้วนำลิงก์มาวางในช่อง URL แทนครับ',
      );
      return;
    }
    setNewUrl(dataUrl);
  };

  const handleAddItem = () => {
    setUploadError(null);
    if (!newName.trim() || !newUrl.trim()) {
      setUploadError('กรุณาระบุชื่อไฟล์และลิงก์ URL (หรือเลือกไฟล์จากเครื่อง)');
      return;
    }
    const created: PublicMediaItem = {
      id: `media-${Date.now()}`,
      name: newName.trim(),
      type: newType,
      folder: newFolder,
      url: newUrl.trim(),
      sizeLabel: newSizeLabel.trim() || 'ลิงก์ภายนอก',
      uploadedAt: new Date().toISOString().slice(0, 10),
    };
    onChange([created, ...items]);
    setNewName('');
    setNewUrl('');
    setNewSizeLabel('ลิงก์ภายนอก');
    setAddOpen(false);
  };

  const resolveThumb = (item: PublicMediaItem) => {
    if (item.type !== 'image') return null;
    return logoSrc(item.url) ?? item.url;
  };

  return (
    <div className="space-y-4">
      {/* Header & Summary */}
      <div className="card">
        <div className="card-body flex flex-wrap items-center justify-between gap-3">
          <div>
            <h3 className="text-sm font-bold text-ink">
              คลังสื่อและเอกสารดิจิทัล (Media Library)
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              รวมรูปภาพ แบนเนอร์ และไฟล์ PDF ของโรงเรียนไว้จุดเดียว
              คัดลอกลิงก์ไปใช้ในข่าวประชาสัมพันธ์หรือหน้ารับสมัครได้ทันที
              (อย่าลืมกด &ldquo;บันทึกการตั้งค่า&rdquo; ด้านบนหลังเพิ่ม/ลบไฟล์)
            </p>
          </div>
          <div className="flex items-center gap-2">
            <div className="seg">
              <button
                type="button"
                onClick={() => setViewMode('grid')}
                className={viewMode === 'grid' ? 'active' : ''}
                title="มุมมองการ์ด"
              >
                <LayoutGrid className="h-3.5 w-3.5" />
                <span>การ์ด</span>
              </button>
              <button
                type="button"
                onClick={() => setViewMode('table')}
                className={viewMode === 'table' ? 'active' : ''}
                title="มุมมองตาราง"
              >
                <List className="h-3.5 w-3.5" />
                <span>ตาราง</span>
              </button>
            </div>
            <button
              type="button"
              onClick={() => {
                setUploadError(null);
                setAddOpen(true);
              }}
              className="btn-primary"
            >
              <Plus className="h-4 w-4" />
              <span>เพิ่มสื่อ / เอกสาร</span>
            </button>
          </div>
        </div>
      </div>

      {/* Filters & Bulk Bar */}
      <div className="card">
        <div className="card-body space-y-4">
          {selectedIds.size > 0 && (
            <div className="flex flex-wrap items-center justify-between gap-2.5 rounded-xl border border-brand-200 bg-brand-50/80 px-4 py-2.5">
              <span className="text-xs font-bold text-brand-800">
                จัดการแบบกลุ่ม ({selectedIds.size} ไฟล์)
              </span>
              <div className="flex flex-wrap items-center gap-2">
                <div className="inline-flex items-center gap-1.5 text-xs">
                  <FolderInput className="h-3.5 w-3.5 text-slate-500" />
                  <select
                    defaultValue=""
                    onChange={(e) => {
                      const val = e.target.value as PublicMediaItem['folder'];
                      if (val) handleBulkMoveFolder(val);
                      e.target.value = '';
                    }}
                    className="input w-auto py-1 text-xs"
                  >
                    <option value="">ย้ายไปโฟลเดอร์...</option>
                    {FOLDERS.map((f) => (
                      <option key={f} value={f}>
                        {f}
                      </option>
                    ))}
                  </select>
                </div>
                <button
                  type="button"
                  onClick={handleBulkDelete}
                  className="btn-danger btn-sm"
                >
                  <Trash2 className="h-3.5 w-3.5" />
                  <span>ลบที่เลือก ({selectedIds.size})</span>
                </button>
                <button
                  type="button"
                  onClick={() => setSelectedIds(new Set())}
                  className="text-xs text-slate-500 hover:text-ink px-2"
                >
                  ยกเลิก
                </button>
              </div>
            </div>
          )}

          <div className="flex flex-wrap items-center gap-2.5">
            <div className="relative flex-1 min-w-[220px]">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="ค้นหาชื่อไฟล์ หรือโฟลเดอร์..."
                className="input pl-9"
              />
            </div>
            <select
              value={folderFilter}
              onChange={(e) =>
                setFolderFilter(
                  e.target.value as 'all' | PublicMediaItem['folder'],
                )
              }
              className="input w-auto"
            >
              <option value="all">ทุกโฟลเดอร์ ({items.length})</option>
              {FOLDERS.map((f) => (
                <option key={f} value={f}>
                  {f}
                </option>
              ))}
            </select>
            <select
              value={typeFilter}
              onChange={(e) =>
                setTypeFilter(e.target.value as 'all' | 'image' | 'document')
              }
              className="input w-auto"
            >
              <option value="all">ทุกประเภทไฟล์</option>
              <option value="image">รูปภาพ</option>
              <option value="document">เอกสาร / PDF</option>
            </select>
          </div>

          {filtered.length === 0 ? (
            <div className="py-12 text-center text-sm text-slate-500">
              ไม่พบสื่อหรือเอกสารที่ตรงกับเงื่อนไขการค้นหา
            </div>
          ) : viewMode === 'grid' ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              {filtered.map((item) => {
                const checked = selectedIds.has(item.id);
                const thumb = resolveThumb(item);
                return (
                  <div
                    key={item.id}
                    className={`rounded-xl border overflow-hidden bg-white transition-all flex flex-col ${
                      checked
                        ? 'border-brand-500 ring-2 ring-brand-100'
                        : 'border-slate-200 hover:border-slate-300'
                    }`}
                  >
                    <div className="relative h-36 bg-slate-100 flex items-center justify-center overflow-hidden">
                      {thumb ? (
                        <img
                          src={thumb}
                          alt={item.name}
                          onClick={() => setPreviewItem(item)}
                          className="w-full h-full object-cover cursor-pointer hover:scale-105 transition-transform"
                        />
                      ) : (
                        <button
                          type="button"
                          onClick={() => setPreviewItem(item)}
                          className="flex flex-col items-center gap-1.5 text-slate-400 hover:text-brand-600"
                        >
                          <FileText className="h-10 w-10" />
                          <span className="text-[11px] font-semibold">
                            เอกสาร / PDF
                          </span>
                        </button>
                      )}
                      <input
                        type="checkbox"
                        checked={checked}
                        onChange={() => toggleSelect(item.id)}
                        className="checkbox absolute top-2.5 left-2.5 bg-white"
                        aria-label={`เลือก ${item.name}`}
                      />
                      <span className="absolute top-2.5 right-2.5 rounded-full bg-slate-900/70 px-2 py-0.5 text-[10px] font-medium text-white">
                        {item.folder}
                      </span>
                    </div>

                    <div className="p-3 flex-1 flex flex-col justify-between gap-2">
                      <div>
                        <p
                          className="text-xs font-semibold text-ink truncate"
                          title={item.name}
                        >
                          {item.name}
                        </p>
                        <p className="text-[11px] text-slate-400 mt-0.5">
                          {item.sizeLabel} • {item.uploadedAt}
                        </p>
                      </div>
                      <div className="flex items-center justify-between gap-1.5 pt-1 border-t border-slate-100">
                        <button
                          type="button"
                          onClick={() => handleCopyUrl(item)}
                          className="btn-secondary btn-sm flex-1 justify-center text-[11px]"
                        >
                          {copiedId === item.id ? (
                            <>
                              <Check className="h-3 w-3 text-emerald-600" />
                              <span>คัดลอกแล้ว</span>
                            </>
                          ) : (
                            <>
                              <Copy className="h-3 w-3" />
                              <span>คัดลอกลิงก์</span>
                            </>
                          )}
                        </button>
                        <button
                          type="button"
                          onClick={() =>
                            onChange(items.filter((x) => x.id !== item.id))
                          }
                          className="rounded-lg border border-rose-200 p-1.5 text-rose-600 hover:bg-rose-50"
                          title="ลบไฟล์"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-slate-200 text-slate-500">
                    <th className="py-2.5 pr-2 w-8" />
                    <th className="py-2.5 px-3 font-semibold">ชื่อไฟล์</th>
                    <th className="py-2.5 px-3 font-semibold">ประเภท</th>
                    <th className="py-2.5 px-3 font-semibold">โฟลเดอร์</th>
                    <th className="py-2.5 px-3 font-semibold">ขนาด / วันที่</th>
                    <th className="py-2.5 pl-3 text-right font-semibold">
                      จัดการ
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filtered.map((item) => (
                    <tr key={item.id} className="hover:bg-slate-50/80">
                      <td className="py-2.5 pr-2">
                        <input
                          type="checkbox"
                          checked={selectedIds.has(item.id)}
                          onChange={() => toggleSelect(item.id)}
                          className="checkbox"
                        />
                      </td>
                      <td className="py-2.5 px-3 font-semibold text-ink">
                        <button
                          type="button"
                          onClick={() => setPreviewItem(item)}
                          className="inline-flex items-center gap-2 hover:text-brand-600 text-left"
                        >
                          {item.type === 'image' ? (
                            <ImageIcon className="h-4 w-4 text-brand-500 shrink-0" />
                          ) : (
                            <FileText className="h-4 w-4 text-rose-500 shrink-0" />
                          )}
                          <span className="truncate max-w-[260px]">
                            {item.name}
                          </span>
                        </button>
                      </td>
                      <td className="py-2.5 px-3 text-slate-600">
                        {item.type === 'image' ? 'รูปภาพ' : 'เอกสาร'}
                      </td>
                      <td className="py-2.5 px-3">
                        <span className="badge-slate">{item.folder}</span>
                      </td>
                      <td className="py-2.5 px-3 text-slate-500">
                        {item.sizeLabel} • {item.uploadedAt}
                      </td>
                      <td className="py-2.5 pl-3 text-right whitespace-nowrap space-x-1.5">
                        <button
                          type="button"
                          onClick={() => handleCopyUrl(item)}
                          className="btn-secondary btn-sm"
                        >
                          {copiedId === item.id ? 'คัดลอกแล้ว' : 'คัดลอกลิงก์'}
                        </button>
                        <button
                          type="button"
                          onClick={() =>
                            onChange(items.filter((x) => x.id !== item.id))
                          }
                          className="inline-flex items-center rounded-lg border border-rose-200 p-1.5 text-rose-600 hover:bg-rose-50"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* Add Media Modal */}
      {addOpen && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/50 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setAddOpen(false)}
        >
          <div
            className="w-full max-w-lg rounded-2xl bg-white shadow-2xl border border-slate-200 overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-slate-200 px-6 py-4">
              <div className="flex items-center gap-2">
                <Upload className="h-4 w-4 text-brand-600" />
                <h3 className="text-base font-bold text-ink">
                  เพิ่มสื่อหรือเอกสารเข้าคลังกลาง
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setAddOpen(false)}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="p-6 space-y-4">
              <div className="rounded-xl border border-dashed border-slate-300 bg-slate-50 p-4 text-center">
                <p className="text-xs font-semibold text-slate-700">
                  เลือกไฟล์จากเครื่อง (ไม่เกิน 450 KB) หรือวางลิงก์ URL / Google Drive ด้านล่าง
                </p>
                <input
                  type="file"
                  accept="image/*,.pdf"
                  onChange={(e) =>
                    handleLocalFilePick(e.target.files?.[0] ?? null)
                  }
                  className="mt-2 text-xs text-slate-600"
                />
              </div>

              <div>
                <label className="label">ชื่อไฟล์ / ชื่อเรียกสื่อ *</label>
                <input
                  className="input"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  placeholder="เช่น ภาพกิจกรรมวันไหว้ครู_2568.jpg หรือ ประกาศรับสมัคร.pdf"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="label">ประเภทไฟล์</label>
                  <select
                    className="input"
                    value={newType}
                    onChange={(e) =>
                      setNewType(e.target.value as 'image' | 'document')
                    }
                  >
                    <option value="image">รูปภาพ</option>
                    <option value="document">เอกสาร / PDF</option>
                  </select>
                </div>
                <div>
                  <label className="label">โฟลเดอร์จัดเก็บ</label>
                  <select
                    className="input"
                    value={newFolder}
                    onChange={(e) =>
                      setNewFolder(e.target.value as PublicMediaItem['folder'])
                    }
                  >
                    {FOLDERS.map((f) => (
                      <option key={f} value={f}>
                        {f}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="label">ลิงก์ไฟล์ (URL / Google Drive) *</label>
                <input
                  className="input"
                  value={newUrl}
                  onChange={(e) => setNewUrl(e.target.value)}
                  placeholder="https://... หรือ https://drive.google.com/file/d/..."
                />
              </div>

              {uploadError && (
                <div className="alert-error text-xs">{uploadError}</div>
              )}
            </div>

            <div className="flex items-center justify-end gap-2.5 border-t border-slate-200 bg-slate-50 px-6 py-3.5">
              <button
                type="button"
                onClick={() => setAddOpen(false)}
                className="btn-secondary"
              >
                ยกเลิก
              </button>
              <button
                type="button"
                onClick={handleAddItem}
                className="btn-primary"
              >
                เพิ่มเข้าคลังสื่อ
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Preview Modal */}
      {previewItem && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setPreviewItem(null)}
        >
          <div
            className="w-full max-w-2xl rounded-2xl bg-white shadow-2xl border border-slate-200 overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-slate-200 px-5 py-3.5">
              <div className="min-w-0">
                <h4 className="text-sm font-bold text-ink truncate">
                  {previewItem.name}
                </h4>
                <p className="text-[11px] text-slate-500">
                  {previewItem.folder} • {previewItem.sizeLabel} •{' '}
                  {previewItem.uploadedAt}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setPreviewItem(null)}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              {previewItem.type === 'image' ? (
                <img
                  src={resolveThumb(previewItem) || previewItem.url}
                  alt={previewItem.name}
                  className="w-full max-h-[420px] object-contain rounded-xl bg-slate-100"
                />
              ) : (
                <div className="rounded-xl bg-slate-50 border border-slate-200 p-8 text-center space-y-2">
                  <FileText className="h-12 w-12 text-brand-600 mx-auto" />
                  <p className="text-sm font-semibold text-ink">
                    {previewItem.name}
                  </p>
                  <a
                    href={previewItem.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn-primary btn-sm inline-flex"
                  >
                    <ExternalLink className="h-3.5 w-3.5" />
                    <span>เปิดไฟล์ในแท็บใหม่</span>
                  </a>
                </div>
              )}

              <div className="flex items-center gap-2">
                <input
                  readOnly
                  value={previewItem.url}
                  className="input text-xs bg-slate-50 flex-1"
                />
                <button
                  type="button"
                  onClick={() => handleCopyUrl(previewItem)}
                  className="btn-primary btn-sm shrink-0"
                >
                  <Copy className="h-3.5 w-3.5" />
                  <span>
                    {copiedId === previewItem.id ? 'คัดลอกแล้ว' : 'คัดลอกลิงก์'}
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
