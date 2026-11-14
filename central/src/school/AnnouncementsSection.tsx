import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { Megaphone, Pin, Plus, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';

interface AnnouncementsSectionProps {
  schoolId: number | null;
  canEdit: boolean;
}

interface AnnouncementRow {
  id: number;
  title: string;
  content: string | null;
  category: 'general' | 'academic' | 'hr';
  is_pinned: boolean;
  published_at: string;
}

const CATEGORY_LABEL: Record<AnnouncementRow['category'], string> = {
  general: 'ทั่วไป',
  academic: 'วิชาการ',
  hr: 'งานบุคคล',
};

export default function AnnouncementsSection({
  schoolId,
  canEdit,
}: AnnouncementsSectionProps) {
  const [items, setItems] = useState<AnnouncementRow[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [category, setCategory] = useState<AnnouncementRow['category']>('general');
  const [isPinned, setIsPinned] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    if (!schoolId) return;
    const { data } = await supabase
      .from('SchoolWebAnnouncements')
      .select('id, title, content, category, is_pinned, published_at')
      .eq('id_school', schoolId)
      .order('is_pinned', { ascending: false })
      .order('published_at', { ascending: false })
      .limit(6);

    setItems((data as AnnouncementRow[] | null) ?? []);
  }, [schoolId]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleAdd(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);

    const { error } = await supabase.from('SchoolWebAnnouncements').insert({
      id_school: schoolId,
      title: title.trim(),
      content: content.trim() || null,
      category,
      is_pinned: isPinned,
    });

    if (!error) {
      setTitle('');
      setContent('');
      setIsPinned(false);
      setShowForm(false);
      await load();
    }
    setBusy(false);
  }

  async function removeItem(id: number) {
    if (!canEdit) return;
    setBusy(true);
    await supabase.from('SchoolWebAnnouncements').delete().eq('id', id);
    await load();
    setBusy(false);
  }

  return (
    <section className="surface-card p-6">
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Megaphone className="h-[18px] w-[18px] text-brand-600" strokeWidth={1.5} />
          <h2 className="text-base font-semibold text-ink">ประกาศโรงเรียน</h2>
        </div>

        {canEdit && (
          <button
            type="button"
            onClick={() => setShowForm((prev) => !prev)}
            className="text-xs font-medium text-brand-600 hover:text-brand-700"
          >
            {showForm ? 'ยกเลิก' : 'เพิ่มประกาศ'}
          </button>
        )}
      </div>

      {canEdit && showForm && (
        <form
          onSubmit={handleAdd}
          className="mt-4 space-y-3 rounded-lg border border-line bg-canvas/60 p-4"
        >
          <input
            type="text"
            required
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="หัวข้อประกาศ"
            className="input"
          />
          <textarea
            rows={2}
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="รายละเอียดเพิ่มเติม (ไม่บังคับ)"
            className="input"
          />
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <select
                value={category}
                onChange={(e) =>
                  setCategory(e.target.value as AnnouncementRow['category'])
                }
                className="rounded-lg border border-line bg-white px-2.5 py-1.5 text-xs text-ink outline-none focus:border-brand-500"
              >
                <option value="general">ทั่วไป</option>
                <option value="academic">วิชาการ</option>
                <option value="hr">งานบุคคล</option>
              </select>
              <label className="flex cursor-pointer items-center gap-1.5 text-xs text-slate-600">
                <input
                  type="checkbox"
                  checked={isPinned}
                  onChange={(e) => setIsPinned(e.target.checked)}
                />
                <span>ปักหมุด</span>
              </label>
            </div>
            <button type="submit" disabled={busy} className="btn-primary btn-sm">
              <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
              <span>เผยแพร่</span>
            </button>
          </div>
        </form>
      )}

      {items.length === 0 ? (
        <p className="mt-4 text-sm text-slate-500">ยังไม่มีประกาศข่าวสาร</p>
      ) : (
        <ul className="mt-4 divide-y divide-line">
          {items.map((item) => (
            <li key={item.id} className="flex items-start justify-between gap-3 py-3">
              <div className="min-w-0">
                <div className="flex items-center gap-1.5">
                  {item.is_pinned && (
                    <Pin className="h-3.5 w-3.5 shrink-0 text-brand-600" strokeWidth={1.5} />
                  )}
                  <p className="text-sm font-medium text-ink">{item.title}</p>
                  <span className="rounded bg-slate-100 px-1.5 py-0.5 text-[11px] text-slate-600">
                    {CATEGORY_LABEL[item.category]}
                  </span>
                </div>
                {item.content && (
                  <p className="mt-1 text-xs text-slate-600">{item.content}</p>
                )}
                <p className="mt-1 tabular-nums text-[11px] text-slate-400">
                  {new Date(item.published_at).toLocaleDateString('th-TH', {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                  })}
                </p>
              </div>

              {canEdit && (
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => removeItem(item.id)}
                  className="rounded p-1 text-slate-400 hover:bg-red-50 hover:text-red-600"
                  title="ลบประกาศ"
                >
                  <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                </button>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
