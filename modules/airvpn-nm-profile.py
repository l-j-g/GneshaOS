#!/usr/bin/env python3
"""Convert a restricted wg-quick profile into a NetworkManager keyfile."""

import base64
import ipaddress
import os
import sys
import tempfile
import uuid


class ProfileError(Exception):
    pass


def parse_profile(path):
    sections = []
    current = None
    with open(path, encoding="utf-8") as profile:
        for line_number, raw_line in enumerate(profile, 1):
            line = raw_line.strip()
            if not line or line.startswith(("#", ";")):
                continue
            if line.startswith("[") and line.endswith("]"):
                name = line[1:-1]
                if name not in ("Interface", "Peer"):
                    raise ProfileError(f"unsupported section at line {line_number}")
                current = {}
                sections.append((name, current))
                continue
            if current is None or "=" not in line:
                raise ProfileError(f"invalid profile syntax at line {line_number}")
            key, value = (part.strip() for part in line.split("=", 1))
            key = key.lower()
            if not key or key in current:
                raise ProfileError(f"empty or repeated setting at line {line_number}")
            current[key] = value

    if not sections or sections[0][0] != "Interface":
        raise ProfileError("profile must begin with an Interface section")
    if sum(name == "Interface" for name, _ in sections) != 1:
        raise ProfileError("profile must contain exactly one Interface section")

    interface = sections[0][1]
    interface_keys = {"privatekey", "address", "dns", "mtu", "listenport", "table"}
    peer_keys = {
        "publickey", "presharedkey", "allowedips", "endpoint", "persistentkeepalive"
    }
    unknown = set(interface) - interface_keys
    if unknown:
        raise ProfileError("unsupported Interface setting: " + ", ".join(sorted(unknown)))
    peers = []
    peer_keys_seen = set()
    for name, peer in sections[1:]:
        if name != "Peer":
            raise ProfileError("only Peer sections may follow Interface")
        unknown = set(peer) - peer_keys
        if unknown:
            raise ProfileError("unsupported Peer setting: " + ", ".join(sorted(unknown)))
        peer_public_key = decode_key(peer.get("publickey"), "Peer PublicKey")
        if peer_public_key in peer_keys_seen:
            raise ProfileError("Peer PublicKey must be unique")
        peer_keys_seen.add(peer_public_key)
        peers.append(peer)

    private_key = decode_key(interface.get("privatekey"), "Interface PrivateKey")
    if not peers:
        raise ProfileError("profile must contain at least one Peer")
    for peer in peers:
        peer["publickey"] = decode_key(peer.get("publickey"), "Peer PublicKey")
        if "presharedkey" in peer:
            peer["presharedkey"] = decode_key(peer["presharedkey"], "Peer PresharedKey")
        if "allowedips" not in peer:
            raise ProfileError("every Peer must define AllowedIPs")
        peer["allowedips"] = split_values(peer["allowedips"])
        if not peer["allowedips"]:
            raise ProfileError("every Peer must define at least one AllowedIP")
        for value in peer["allowedips"]:
            try:
                ipaddress.ip_network(value, strict=False)
            except ValueError as error:
                raise ProfileError("AllowedIPs contains an invalid IP prefix") from error
        if "persistentkeepalive" in peer:
            bounded_int(peer["persistentkeepalive"], "PersistentKeepalive", 0, 65535)
        if "endpoint" in peer and not peer["endpoint"]:
            raise ProfileError("Peer Endpoint must not be empty")

    addresses = split_values(interface.get("address", ""))
    for address in addresses:
        try:
            ipaddress.ip_interface(address)
        except ValueError as error:
            raise ProfileError("Address contains an invalid IP prefix") from error
    dns_servers = split_values(interface.get("dns", ""))
    for server in dns_servers:
        try:
            ipaddress.ip_address(server)
        except ValueError as error:
            raise ProfileError("DNS contains an invalid IP address") from error
    mtu = interface.get("mtu")
    if mtu is not None:
        bounded_int(mtu, "MTU", 576, 65535)
    listen_port = interface.get("listenport")
    if listen_port is not None:
        bounded_int(listen_port, "ListenPort", 0, 65535)
    table = interface.get("table", "auto").lower()
    if table not in ("auto", "off"):
        raise ProfileError("Table must be auto or off for NetworkManager")

    return private_key, interface, peers, addresses, dns_servers, table


def decode_key(value, label):
    try:
        decoded = base64.b64decode(value or "", validate=True)
    except Exception as error:
        raise ProfileError(f"{label} is not valid base64") from error
    if len(decoded) != 32:
        raise ProfileError(f"{label} must decode to 32 bytes")
    return value


def split_values(value):
    return [item for item in value.replace(",", " ").split() if item]


def bounded_int(value, label, minimum, maximum):
    try:
        result = int(value)
    except ValueError as error:
        raise ProfileError(f"{label} must be an integer") from error
    if not minimum <= result <= maximum:
        raise ProfileError(f"{label} is outside the supported range")
    return result


def keyfile_lines(profile_path):
    private_key, interface, peers, addresses, dns_servers, table = parse_profile(
        profile_path
    )
    lines = [
        "[connection]",
        "id=AirVPN",
        "uuid=" + str(uuid.uuid5(uuid.NAMESPACE_URL, "gneshaos-airvpn-host")),
        "type=wireguard",
        "interface-name=airvpn-wg",
        "autoconnect=false",
        "",
        "[wireguard]",
        "private-key=" + private_key,
        "peer-routes=" + ("false" if table == "off" else "true"),
    ]
    if "mtu" in interface:
        lines.append("mtu=" + interface["mtu"])
    if "listenport" in interface:
        lines.append("listen-port=" + interface["listenport"])

    for peer in peers:
        lines.extend(["", "[wireguard-peer." + peer["publickey"] + "]"])
        if "endpoint" in peer:
            lines.append("endpoint=" + peer["endpoint"])
        lines.append("allowed-ips=" + ";".join(peer["allowedips"]) + ";")
        if "presharedkey" in peer:
            lines.append("preshared-key=" + peer["presharedkey"])
        if peer.get("persistentkeepalive") not in (None, "0"):
            lines.append("persistent-keepalive=" + peer["persistentkeepalive"])

    v4_addresses = [address for address in addresses if "." in address]
    v6_addresses = [address for address in addresses if ":" in address]
    v4_dns = [server for server in dns_servers if "." in server]
    v6_dns = [server for server in dns_servers if ":" in server]
    lines.extend(["", "[ipv4]"])
    if v4_addresses:
        lines.append("method=manual")
        for index, address in enumerate(v4_addresses, 1):
            lines.append(f"address{index}={address}")
    else:
        lines.append("method=disabled")
    if v4_dns:
        lines.append("dns=" + ";".join(v4_dns) + ";")
    if dns_servers:
        lines.append("dns-priority=-50")
    lines.extend(["", "[ipv6]"])
    if v6_addresses:
        lines.append("method=manual")
        for index, address in enumerate(v6_addresses, 1):
            lines.append(f"address{index}={address}")
    else:
        lines.append("method=ignore")
    if v6_dns:
        lines.append("dns=" + ";".join(v6_dns) + ";")
    if dns_servers:
        lines.append("dns-priority=-50")
    return "\n".join(lines) + "\n"


def main():
    if len(sys.argv) != 3:
        raise ProfileError("usage: converter PROFILE DESTINATION")
    source, destination = sys.argv[1:]
    content = keyfile_lines(source)
    directory = os.path.dirname(destination)
    os.makedirs(directory, mode=0o700, exist_ok=True)
    metadata = os.stat(directory, follow_symlinks=False)
    if not os.path.isdir(directory) or metadata.st_uid != 0 or metadata.st_mode & 0o022:
        raise ProfileError("NetworkManager connection directory is not trusted")
    if os.path.realpath(directory) != directory:
        raise ProfileError("NetworkManager connection directory contains a symlink")
    if os.path.islink(destination):
        raise ProfileError("existing NetworkManager connection is a symlink")
    fd, temporary = tempfile.mkstemp(prefix=".airvpn-", dir=directory)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, destination)
        os.chown(destination, 0, 0)
        os.chmod(destination, 0o600)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ProfileError, ValueError) as error:
        print(f"AirVPN NetworkManager profile rejected: {error}", file=sys.stderr)
        sys.exit(1)
