"""Gold projections for streaming activity and the synthetic venue business."""
from collections import Counter, defaultdict
from datetime import timezone

import pyarrow as pa

SHOWS = (
    ("EV01", "Indie Nights", "Concert", 16, 420_000),
    ("EV02", "City Jazz", "Concert", 24, 650_000),
    ("EV03", "Animation Weekend", "Screening", 20, 180_000),
    ("EV04", "Film Premiere", "Screening", 28, 250_000),
    ("EV05", "Comedy Live", "Comedy", 18, 340_000),
    ("EV06", "Studio Sessions", "Workshop", 14, 280_000),
)
DEMO_USERS = tuple(f"usr_demo_{i:03d}" for i in range(1, 33))


def schema(text, numbers):
    return pa.schema([(name, pa.string()) for name in text.split()] +
                     [(name, pa.int64()) for name in numbers.split()])


BUSINESS = {
    "hourly_user_activity": schema("hour_utc", "event_count play_count active_users watch_seconds"),
    "event_performance": schema("show_id show_name category", "capacity sold checked_in net_revenue_vnd"),
    "booking_transactions": schema("booking_status", "booking_count payments_captured payments_declined refunds gross_vnd refund_vnd"),
    "customer_360": schema("customer_id membership last_stream_utc", "streaming_events plays watch_seconds bookings confirmed net_spend_vnd check_ins"),
}


def venue_events():
    """Yield deterministic source booking records with captured/refunded payment facts."""
    for show_index, (show_id, _, _, capacity, price) in enumerate(SHOWS):
        for seat in range(capacity - show_index % 4 + 3):
            status = ("Pending payment" if seat % 7 == 0 else
                      "Cancelled" if seat % 6 == 0 else "Confirmed")
            captured = status != "Pending payment"
            refunded = status == "Cancelled"
            yield {
                "booking_id": f"{show_id}-{seat + 1:03}", "show_id": show_id,
                "customer_id": DEMO_USERS[(seat * 3 + show_index * 7) % len(DEMO_USERS)],
                "status": status, "captured": captured, "declined": not captured,
                "refunded": refunded, "gross": price if captured else 0,
                "refund": price if refunded else 0,
                "checked_in": status == "Confirmed" and (seat + show_index) % 5 != 0,
            }


def stream_key(row):
    return row["event_timestamp"].astimezone(timezone.utc)


def projections(stream):
    hours = defaultdict(Counter)
    active = defaultdict(set)
    profiles = {
        user: dict(customer_id=user, membership=("Premium", "Standard", "Free")[i % 3],
                   last_stream_utc="", streaming_events=0, plays=0, watch_seconds=0,
                   bookings=0, confirmed=0, net_spend_vnd=0, check_ins=0)
        for i, user in enumerate(DEMO_USERS)
    }
    for row in stream:
        stamp = stream_key(row)
        hour = stamp.strftime("%Y-%m-%d %H:00")
        user = row["user_id"]
        play = row["event_type"] == "PLAY"
        active[hour].add(user)
        hours[hour].update(event_count=1, play_count=int(play), watch_seconds=row["watch_duration_seconds"])
        if user in profiles:
            profile = profiles[user]
            profile["streaming_events"] += 1
            profile["plays"] += play
            profile["watch_seconds"] += row["watch_duration_seconds"]
            profile["last_stream_utc"] = max(profile["last_stream_utc"], stamp.strftime("%Y-%m-%d %H:%M:%S"))
    show_rows = {
        key: dict(show_id=key, show_name=name, category=category, capacity=capacity,
                  sold=0, checked_in=0, net_revenue_vnd=0)
        for key, name, category, capacity, _ in SHOWS
    }
    status_rows = defaultdict(Counter)
    for booking in venue_events():
        status = booking["status"]
        sold = status == "Confirmed"
        net = booking["gross"] - booking["refund"]
        show = show_rows[booking["show_id"]]
        show["sold"] += sold
        show["checked_in"] += booking["checked_in"]
        show["net_revenue_vnd"] += net
        status_rows[status].update(
            booking_count=1, payments_captured=int(booking["captured"]),
            payments_declined=int(booking["declined"]), refunds=int(booking["refunded"]),
            gross_vnd=booking["gross"], refund_vnd=booking["refund"],
        )
        profile = profiles[booking["customer_id"]]
        profile["bookings"] += 1
        profile["confirmed"] += sold
        profile["net_spend_vnd"] += net
        profile["check_ins"] += booking["checked_in"]
    activity = [dict(hour_utc=key, active_users=len(active[key]), **counts)
                for key, counts in sorted(hours.items())]
    bookings = [dict(booking_status=key, **counts) for key, counts in sorted(status_rows.items())]
    for profile in profiles.values():
        profile['last_stream_utc'] = profile['last_stream_utc'] or None
    return activity, list(show_rows.values()), bookings, list(profiles.values())
