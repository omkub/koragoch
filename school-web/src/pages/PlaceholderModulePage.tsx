interface PlaceholderModulePageProps {
  title: string;
  partLabel: string;
  description: string;
}

export default function PlaceholderModulePage({
  title,
  partLabel,
  description,
}: PlaceholderModulePageProps) {
  return (
    <div className="surface-card p-8">
      <p className="text-xs font-medium text-brand-600">{partLabel}</p>
      <h1 className="mt-1 text-xl font-semibold text-ink">{title}</h1>
      <p className="mt-2 max-w-xl text-sm text-slate-600">{description}</p>
    </div>
  );
}
