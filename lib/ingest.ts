/*
  Reading GoHighLevel webhooks into the GRAIN shape (used by app/api/ingest/[source]/route.ts).

  A GoHighLevel workflow can send the GRAIN shape ({ type, id, org, ...fields }) two ways:
    1. Custom Webhook action: the whole JSON body is the GRAIN shape, the key goes in the x-grain-key header.
    2. Standard Webhook action: the GRAIN fields go in as Custom Data items (type, id, and the rest),
       the key goes in the address (?key=...), and the sub-account comes from location.id when org is left out.
  Anything else is kept whole and shown in HQ as unprocessed, so the first real payloads show us
  exactly what GoHighLevel sends before a mapping is added for it.
*/
import { createHash } from "node:crypto";

type Json = Record<string, unknown>;
const str = (v: unknown) => (typeof v === "string" && v.trim() && v.trim() !== "undefined" && v.trim() !== "null" ? v.trim().slice(0, 200) : undefined);
const obj = (v: unknown) => (v && typeof v === "object" && !Array.isArray(v) ? (v as Json) : undefined);

export type Mapped = { type?: string; id?: string; org?: string; payload: Json };

/** The sub-account a standard GoHighLevel webhook came from. */
function locationOf(body: Json): string | undefined {
  return str(obj(body.location)?.id) ?? str(body.locationId) ?? str(body.location_id);
}

export function fromGhl(body: Json): Mapped {
  if (str(body.type)) {
    const { type, id, org, ...rest } = body;
    return { type: str(type), id: str(id), org: str(org) ?? locationOf(body), payload: rest };
  }
  const data = obj(body.customData) ?? obj(body.custom_data) ?? obj(body.customdata);
  if (data && str(data.type)) {
    const { type, id, org, ...rest } = data;
    const contact = str(body.contact_id) ?? str(obj(body.contact)?.id);
    return { type: str(type), id: str(id), org: str(org) ?? locationOf(body), payload: contact ? { ...rest, contact_id: contact } : rest };
  }
  return { org: locationOf(body), payload: body };
}

/** When the sender gave no id: the same body always gets the same id, so a retried webhook is only counted once. */
export function fallbackId(source: string, body: Json): string {
  return `${source}-` + createHash("sha256").update(JSON.stringify(body)).digest("hex").slice(0, 32);
}
