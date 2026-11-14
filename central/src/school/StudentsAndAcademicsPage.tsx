import { useState } from 'react';
import AcademicsPage from './AcademicsPage';
import StudentsPage from './StudentsPage';

interface StudentsAndAcademicsPageProps {
  schoolId: number | null;
  canEdit: boolean;
}

export default function StudentsAndAcademicsPage({
  schoolId,
  canEdit,
}: StudentsAndAcademicsPageProps) {
  const [section, setSection] = useState<'students' | 'academics'>('students');

  return (
    <div className="space-y-6">
      <div className="border-b border-line pb-3">
        <div className="flex flex-wrap items-center gap-1.5">
          <button
            type="button"
            onClick={() => setSection('students')}
            className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
              section === 'students'
                ? 'bg-brand-600 text-white'
                : 'bg-white text-slate-600 ring-1 ring-line hover:bg-slate-50 hover:text-ink'
            }`}
          >
            ทะเบียนนักเรียนและห้องเรียน
          </button>
          <button
            type="button"
            onClick={() => setSection('academics')}
            className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
              section === 'academics'
                ? 'bg-brand-600 text-white'
                : 'bg-white text-slate-600 ring-1 ring-line hover:bg-slate-50 hover:text-ink'
            }`}
          >
            หลักสูตรและตารางสอน
          </button>
        </div>
      </div>

      {section === 'students' ? (
        <StudentsPage schoolId={schoolId} canEdit={canEdit} />
      ) : (
        <AcademicsPage schoolId={schoolId} canEdit={canEdit} />
      )}
    </div>
  );
}
