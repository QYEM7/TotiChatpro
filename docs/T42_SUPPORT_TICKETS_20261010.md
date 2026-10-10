# T42 — Real customer service ticket backend
New pending migration creates requester-only tickets and a separately scoped
customer support staff registry. Requester can open tickets through an
authenticated rate-limited idempotent RPC; host agency requests require
agency_name and contact. Support agent assignments require Owner approval
and are audited. Owner, designated main partner or explicit support agents
can list/review; ordinary Super Admin and DB employee cannot automatically.
Reviewing a ticket never creates a host agency or changes wallet balances.
Host agency approval remains the distinct restricted agency RPC.
Pending local tests; production never mutated.
Remaining: real in-app ticket UI, notification delivery, SLA and complaints.
T42 stays partial until complete user/employee end-to-end acceptance.
