load("@ytt:data", "data")

def generate_kibana_tls():
  for key in ["tls.crt", "tls.key"]:
    if getattr(data.values.kibana.ingress.tlsCertificate, key):
      return False
    end
  end
  return True
end
