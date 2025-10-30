from urllib.parse import quote


def test_get_activities(client):
    res = client.get("/activities")
    assert res.status_code == 200
    data = res.json()
    # basic shape checks
    assert "Chess Club" in data
    assert isinstance(data["Chess Club"]["participants"], list)


def test_signup_and_unregister(client):
    activity = "Chess Club"
    email = "test_student@example.com"

    # ensure clean start: if present remove it first
    res = client.get("/activities")
    assert res.status_code == 200
    participants = res.json()[activity]["participants"]
    if email in participants:
        r = client.delete(f"/activities/{quote(activity)}/participants?email={quote(email)}")
        assert r.status_code == 200

    # sign up
    r = client.post(f"/activities/{quote(activity)}/signup?email={quote(email)}")
    assert r.status_code == 200
    assert f"Signed up {email}" in r.json()["message"]

    # verify present
    res2 = client.get("/activities")
    assert res2.status_code == 200
    assert email in res2.json()[activity]["participants"]

    # unregister
    r2 = client.delete(f"/activities/{quote(activity)}/participants?email={quote(email)}")
    assert r2.status_code == 200
    assert f"Unregistered {email}" in r2.json()["message"]

    # verify removed
    res3 = client.get("/activities")
    assert email not in res3.json()[activity]["participants"]
