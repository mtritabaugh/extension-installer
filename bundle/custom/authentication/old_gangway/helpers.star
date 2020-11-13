load("@ytt:data", "data")

def generate_gangway_tls():
  for key in ["tls.crt", "tls.key"]:
    if getattr(data.values.gangway.ingress.tlsCertificate, key):
      return False
    end
  end
  return True
end
