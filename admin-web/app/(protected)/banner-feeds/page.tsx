import { getBannerFeed, getCollection } from '@/lib/api';
import { requireAdminSession } from '@/lib/auth';
import { updateBannerFeedAction } from '@/app/(protected)/mutations';

function BannerFeedEditor({
  title,
  feedKey,
  items,
}: {
  title: string;
  feedKey: 'home' | 'traveler';
  items: Array<Record<string, any>>;
}) {
  const pretty = JSON.stringify(
    items.length > 0
      ? items
      : [
          {
            id: `${feedKey}-1`,
            title: '',
            subtitle: '',
            accent: '#59D38C',
            mediaUrl: '',
            mediaType: 'image',
          },
        ],
    null,
    2,
  );

  return (
    <section className="card panel">
      <h3>{title}</h3>
      <div className="muted" style={{ marginBottom: 12 }}>
        Edita el feed en JSON limpio. Cada item acepta: `id`, `title`, `subtitle`, `accent`, `mediaUrl`, `mediaType` (`image` o `video`).
      </div>
      <form action={updateBannerFeedAction} className="stack">
        <input type="hidden" name="feedKey" value={feedKey} />
        <input type="hidden" name="path" value="/banner-feeds" />
        <textarea name="itemsJson" defaultValue={pretty} style={{ minHeight: 360 }} />
        <button className="button primary" type="submit">Guardar {title}</button>
      </form>
    </section>
  );
}

export default async function BannerFeedsPage() {
  await requireAdminSession();
  const [homePayload, travelerPayload] = await Promise.all([
    getBannerFeed('home'),
    getBannerFeed('traveler'),
  ]);

  const homeItems = getCollection<Record<string, any>>(homePayload);
  const travelerItems = getCollection<Record<string, any>>(travelerPayload);

  return (
    <div className="stack">
      <div>
        <h2 style={{ margin: 0 }}>Banner Feed Editor</h2>
        <div className="muted">Control real de carruseles para Usuario y Viajero.</div>
      </div>

      <div className="grid cols-2">
        <BannerFeedEditor title="Banners Usuario" feedKey="home" items={homeItems} />
        <BannerFeedEditor title="Banners Viajero" feedKey="traveler" items={travelerItems} />
      </div>
    </div>
  );
}
