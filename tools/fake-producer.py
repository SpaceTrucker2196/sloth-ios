#!/usr/bin/env python3
"""Fake sloth --data-socket producer for sloth-ios render checks.

Listens on 127.0.0.1 (default port 8765) and emits one JSONL batch
per second with every record type the client renders. Rates are
sinusoidal so sparklines show a real shape. Dev tool only — never
shipped, never imported by app code. See tools/README.md for the
simulator workflow.
"""
import argparse, asyncio, json, math, time

HOSTS = [
    ("142.250.72.14",  "dns.google",        3.2e6),
    ("104.16.132.229", "cdn.cloudflare.com", 1.1e6),
    ("140.82.112.3",   "github.com",        4.4e5),
    ("52.94.236.248",  "aws.amazon.com",    2.1e5),
    ("151.101.1.140",  "reddit.com",        1.6e5),
    ("17.253.144.10",  "apple.com",         9.0e4),
]

def batch(t, tick):
    now = int(t)
    w = lambda p, s: max(0.0, 1 + math.sin(tick / p + s))
    r = []
    # interfaces
    r.append({"type":"iface","ts":now,"name":"en0","rx_bytes":812_000_000+tick*120_000,
              "tx_bytes":98_000_000+tick*22_000,"rx_packets":900_000,"tx_packets":410_000,
              "rx_errors":0,"rx_drops":0,"tx_errors":0,"tx_drops":0,
              "rx_rate":1.4e6*w(7,0),"tx_rate":2.6e5*w(9,2),"mtu":1500,"speed_mbps":1000})
    r.append({"type":"iface","ts":now,"name":"utun4","rx_bytes":52_000_000,"tx_bytes":9_100_000,
              "rx_packets":80_000,"tx_packets":31_000,"rx_errors":0,"rx_drops":0,
              "tx_errors":0,"tx_drops":0,"rx_rate":6.1e4*w(5,1),"tx_rate":1.2e4*w(6,4),"mtu":1280})
    # alerts — the live sloth shape (jsonl_version 2.x): `count`, no
    # first_seen / last_seen; `ts` is the dedup key's last_seen.
    r.append({"type":"alert","ts":now,"title":"THREAT_DOMAIN","detail":"malware.testing.example resolved by 192.168.1.44",
              "key":"threat:malware.testing.example","count":4,"match_ip":"192.0.2.66","sev":2,"ty":3,
              "incident_id":"a1b2c3d4e5f60718"})
    r.append({"type":"alert","ts":now-60,"title":"HTTP_ATTACK_PATH","detail":"GET /.env from 192.168.1.31",
              "key":"http:attack:/.env","count":2,"match_ip":"192.168.1.31","sev":2,"ty":12})
    r.append({"type":"alert","ts":now-300,"title":"TLS_DEPRECATED","detail":"TLS 1.0 from iot-plug.local",
              "key":"tls:old:192.168.1.77","count":9,"match_ip":"192.168.1.77","sev":1,"ty":20})
    # one incident walks create (WARN) -> escalate (CRIT) -> resolve
    inc = {"incident_id":"9f2c41ab77e30d58","key":"mgmtfuzz:ba:ad:f0:0d:00:01","title":"MGMT_FUZZ",
           "ty":31,"technique":"T1499","first_detected":now-tick}
    if tick == 1:
        r.append({**inc,"type":"alert.create","ts":now,"event_id":"9f2c41ab77e30d58-0001","sev":1,
                  "detail":"BSSID ba:ad:f0:0d:00:01 malformed IEs: 3 overrun","evaluations":1,"last_evaluated":now})
    if tick == 4:
        r.append({**inc,"type":"alert.escalate","ts":now,"event_id":"9f2c41ab77e30d58-0002","sev":2,"prev_sev":1,
                  "detail":"BSSID ba:ad:f0:0d:00:01 malformed IEs: 5 overrun","evaluations":36,"last_evaluated":now})
    if tick == 8:
        r.append({**inc,"type":"alert.resolve","ts":now,"event_id":"9f2c41ab77e30d58-0003","sev":2,
                  "reason":"expired","evaluations":36,"last_evaluated":now-300})
    # self-report: the Wi-Fi daemon only, monitor radio gone
    if tick % 5 == 0:
        r.append({"type":"sensor_health","ts":now,"capture_iface":"any","monitor_iface":"alfa0","monitor_err":"",
                  "chan_confirmed_ok":1,"capture_open":1,"capture_running":1,"capture_exit":"none",
                  "capture_drop":12,"capture_ifdrop":0,"monitor_open":1,"monitor_running":0,
                  "monitor_exit":"iface_gone","monitor_drop":0,"monitor_ifdrop":3,"evictions":5,
                  "storage_failures":0,"scope":"none","scope_not_enforced":0,
                  "daemon":"wifi","db_max_mb":512,"jsonl_version":"2.3.0"})
    if tick == 6:
        r.append({"type":"socket_gap","ts":now,"seq":600,"dropped":77,"dropped_total":77})
    # connections
    for i,(ip,host,rate) in enumerate(HOSTS):
        r.append({"type":"connections","ts":now,"src":f"192.168.1.5:5{200+i}","dst":f"{ip}:443",
                  "proto":"tcp","state":"ESTAB","rtt_ms":8+9*w(6,i),"retx":i%3,
                  "rx_bytes":int(rate*40),"tx_bytes":int(rate*6),"age_s":300+40*i})
    r.append({"type":"connections","ts":now,"src":"192.168.1.5:5353","dst":"224.0.0.251:5353",
              "proto":"udp","rx_bytes":48_200,"tx_bytes":51_600})
    # top hosts
    for i,(ip,host,rate) in enumerate(HOSTS):
        r.append({"type":"top_host","ts":now,"ip":ip,"hostname":host,"first_seen":now-4000,
                  "last_seen":now,"conn_count":2+i,"rx_rate":rate*w(8,i),"tx_rate":rate*0.2*w(5,i+2),
                  "rx_bytes":int(rate*900),"tx_bytes":int(rate*130)})
    # dns
    qs = [("dns.google","A","142.250.72.14",0),("github.com","AAAA","2606:50c0::1",0),
          ("ghost.internal","A",None,3),("reddit.com","A","151.101.1.140",0),
          ("spotify.com","HTTPS","35.186.224.25",0)]
    for i,(q,qt,ans,rc) in enumerate(qs):
        e = {"type":"dns","ts":now-i,"src":"192.168.1.44","qname":q,"qtype":qt,"rcode":rc}
        if ans: e["answer"] = ans
        r.append(e)
    # icmp
    r.append({"type":"icmp","ts":now,"src":"192.168.1.1","dst":"192.168.1.5","itype":8,"code":0})
    r.append({"type":"icmp","ts":now-2,"src":"192.168.1.5","dst":"8.8.8.8","itype":0,"code":0})
    # packets
    protos = ["tcp","udp","tcp","tcp","udp"]
    infos  = ["TLS1.3 client hello sni=github.com","DNS query A dns.google","ACK seq=884211",
              "HTTP GET /index.html","QUIC initial dcid=7fa2"]
    for i in range(6):
        r.append({"type":"packet","ts":now,"ts_sec":now,"ts_usec":i*137000,
                  "src":"192.168.1.5","src_port":52000+i,"dst":HOSTS[i%len(HOSTS)][0],
                  "dst_port":443,"proto":protos[i%5],"len":60+197*i,"info":infos[i%5]})
    # wifi
    for i,(ss,ch,sig) in enumerate([("SpaceTruckin",36,-38),("SpaceTruckin-IoT",6,-52),
                                     ("xfinitywifi",1,-78),("NETGEAR-5G",149,-81)]):
        r.append({"type":"wifi_ap","ts":now,"bssid":f"a4:2b:b0:00:00:0{i}","ssid":ss,
                  "signal_dbm":sig,"channel":ch,"enc":"wpa2","status":"connected" if i==0 else None})
        r.append({"type":"beacon","ts":now,"bssid":f"a4:2b:b0:00:00:0{i}","ssid":ss,
                  "signal_dbm":sig,"channel":ch,"enc":"wpa2","last_seen":now,"frame_count":400+i*37})
    for i,ss in enumerate(["SpaceTruckin",None,"CoffeeShopGuest"]):
        e = {"type":"probe_client","ts":now,"mac":f"da:11:32:9f:00:2{i}","signal_dbm":-55-i*9,
             "channel":6,"first_seen":now-900,"last_seen":now-i*20,"frame_count":12+i}
        if ss: e["ssid"] = ss
        r.append(e)
    # lan chatter
    for i,(inst,svc,port) in enumerate([("Living Room TV","_airplay._tcp",7000),
                                        ("sloth on spacemac","_sloth._tcp",8765),
                                        ("Brother HL-2370DW","_ipp._tcp",631),
                                        ("HomePod","_raop._tcp",5000)]):
        r.append({"type":"mdns_service","ts":now,"instance":inst,"service":svc,
                  "ip":f"192.168.1.{30+i}","port":port,"last_seen":now-i*7})
    for i,h in enumerate(["jeffs-ipad","iot-plug","chromecast"]):
        r.append({"type":"dhcp_lease","ts":now-i*5,"ip":f"192.168.1.{60+i}","hostname":h,
                  "expire":now+86400})
    for i,(kind,ip) in enumerate([("urn:schemas-upnp-org:device:InternetGatewayDevice:1","192.168.1.1"),
                                  ("urn:dial-multiscreen-org:device:dial:1","192.168.1.62")]):
        r.append({"type":"ssdp_device","ts":now,"usn":f"uuid:42-{i}","ip":ip,"kind":kind,
                  "nts":"ssdp:alive","last_seen":now-i*11})
    for i in range(4):
        r.append({"type":"arp","ts":now-i,"mac":f"3c:22:fb:00:1a:0{i}","ip":f"192.168.1.{i+1}","iface":"en0"})
    # deauth (one flood)
    r.append({"type":"deauth","ts":now,"src":"a4:2b:b0:00:00:00","dst":"ff:ff:ff:ff:ff:ff",
              "bssid":"a4:2b:b0:00:00:00","reason":7,"first_seen":now-120,"last_seen":now,
              "count":214,"flood":1})
    r.append({"type":"deauth","ts":now-40,"src":"a4:2b:b0:00:00:01","dst":"da:11:32:9f:00:21",
              "bssid":"a4:2b:b0:00:00:01","reason":3,"first_seen":now-500,"last_seen":now-40,
              "count":2,"flood":0})
    # devices + processes (summary counts)
    for i in range(5):
        r.append({"type":"device","ts":now,"mac":f"3c:22:fb:00:1a:0{i}","ip":f"192.168.1.{i+1}",
                  "hostname":f"host-{i}","is_ap":0,"probe_count":0,"sources":3,"last_seen":now})
    for i,(pid,proc) in enumerate([(312,"mDNSResponder"),(9101,"firefox"),(880,"sshd"),(4470,"node")]):
        r.append({"type":"process","ts":now,"pid":pid,"proc":proc,"conn_count":3+i,"tcp_count":2,
                  "udp_count":1,"tx_bytes":1_000_000*(i+1),"rx_bytes":9_000_000*(i+1),
                  "tx_rate":2.0e4*w(7,i),"rx_rate":1.7e5*w(6,i),"ports":[443]})
    return r

async def handle(reader, writer):
    peer = writer.get_extra_info("peername")
    print("client connected:", peer, flush=True)
    tick = 0
    try:
        while True:
            lines = "".join(json.dumps(rec) + "\n" for rec in batch(time.time(), tick))
            writer.write(lines.encode())
            await writer.drain()
            tick += 1
            await asyncio.sleep(1.0)
    except (ConnectionResetError, BrokenPipeError):
        print("client left:", peer, flush=True)

async def main(port):
    server = await asyncio.start_server(handle, "127.0.0.1", port)
    print(f"fake sloth listening on 127.0.0.1:{port}", flush=True)
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int, default=8765)
    asyncio.run(main(ap.parse_args().port))
