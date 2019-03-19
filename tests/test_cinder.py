import pytest


@pytest.mark.headnodes
@pytest.mark.parametrize("name", [
    ("cinder-volume"),
    ("cinder-scheduler"),
])
def test_services(host, name):
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled


@pytest.mark.worknodes
@pytest.mark.parametrize("name", [
    ("cinder-volume"),
    ("cinder-scheduler"),
])
def test_services_not_installed(host, name):
    s = host.package(name)
    assert not s.is_installed
