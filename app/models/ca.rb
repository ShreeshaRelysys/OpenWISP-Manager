# This file is part of the OpenWISP Manager
#
# Copyright (C) 2012 OpenWISP.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'openssl'

#noinspection RubyArgCount
class Ca < ActiveRecord::Base
  acts_as_authorization_object :subject_class_name => 'Operator'

  validates_presence_of :c, :st, :l, :o, :cn
  validates_format_of :c, :with => /\A[\s\w\d\._']+\Z/i
  validates_length_of :c, :maximum => 32
  validates_format_of :st, :with => /\A[\s\w\d\._']+\Z/i
  validates_length_of :st, :maximum => 32
  validates_format_of :l, :with => /\A[\s\w\d\._']+\Z/i
  validates_length_of :l, :maximum => 32
  validates_format_of :o, :with => /\A[\s\w\d\._']+\Z/i
  validates_length_of :o, :maximum => 128
  validates_format_of :cn, :with => /\A[\s\w\d\._']+\Z/i
  validates_length_of :cn, :maximum => 128
  validates_uniqueness_of :cn
  
  attr_readonly :c, :st, :l, :o, :cn

  has_many :x509_certificates, :dependent => :destroy
  has_one :x509_certificate, :as => :certifiable, :dependent => :destroy

  belongs_to :wisp

  somehow_has :many => :access_points, :through => :wisp

  CA_CERT_EXTENSIONS = [
      "basicConstraints = CA:TRUE",
      "nsComment = CA - autogenerated Certificate",
      "keyUsage = cRLSign, keyCertSign"
  ]

  CLIENT_CERT_EXTENSIONS = [
      "basicConstraints = CA:FALSE",
      "nsCertType = client",
      "nsComment = OpenVPN client - autogenerated Certificate",
      "extendedKeyUsage = clientAuth",
      "keyUsage = digitalSignature, keyEncipherment"
  ]

  SERVER_CERT_EXTENSIONS = [
      "basicConstraints = CA:FALSE",
      "nsCertType = server",
      "nsComment = OpenVPN server - autogenerated Certificate",
      "extendedKeyUsage = serverAuth",
      "keyUsage = digitalSignature, keyEncipherment"
  ]

  DEFAULT_CA_KEY_LEN = 2048
  DEFAULT_CA_CRT_VALIDITY_TIME = 20.years # 20 years

  DEFAULT_CERTIFICATE_KEY_LEN = 1024
  DEFAULT_CLIENT_CRT_VALIDITY_TIME = 3.year  # 3 year
  DEFAULT_SERVER_CRT_VALIDITY_TIME = 5.years # 5 years
  
  DEFAULT_TLS_AUTH_KEY_LENGTH = 2048
  DEFAULT_DH_LENGTH = 1024

  after_create { |record|
    _key = OpenSSL::PKey::RSA.generate(DEFAULT_CA_KEY_LEN)

    subject = OpenSSL::X509::Name.parse(record.dn)

    ef = OpenSSL::X509::ExtensionFactory.new

    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = subject
    cert.issuer = subject
    cert.public_key = _key.public_key
    cert.not_before = Time.now
    cert.not_after = cert.not_before + DEFAULT_CA_CRT_VALIDITY_TIME

    ef.subject_certificate = cert
    ef.issuer_certificate = cert

    Ca::CA_CERT_EXTENSIONS.each do |extension|
      cert.add_extension(ef.create_ext_from_string(extension))
    end

    cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash"))
    cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always,issuer:always"))

    cert.sign(_key, OpenSSL::Digest::SHA1.new)

    record.x509_certificate = X509Certificate.create(
        :dn => record.dn,
        :ca => record,
        :certifiable => record,
        :certificate => cert.to_pem,
        :key => _key.to_pem
    )
  }

  def initialize(params = nil)
    super(params)

    self.serial = 1
  end

  # Certifiable interface
  def identifier
    "ca_#{self.id}_" + self.cn.gsub(/\s/, '_')
  end

  def dn
    "/C=#{self.c}/ST=#{self.st}/L=#{self.l}/O=#{self.o}/CN=#{self.cn}"
  end

  def dn_prefix
    "/C=#{self.c}/ST=#{self.st}/L=#{self.l}/O=#{self.o}"
  end

  # Class methods
  def self.generate_dh
    OpenSSL::PKey::DH.new(DEFAULT_DH_LENGTH).to_s
  end

  # 2048 bit OpenVPN static Key
  def self.generate_tls_auth_key
    byte = DEFAULT_TLS_AUTH_KEY_LENGTH/8
    size = 32
    s = ""
    t = ""
    OpenSSL::Random::random_bytes(byte).each_byte { |b| s+= "%02x" % b }
    (0..(s.length-1)/size).each do |i|
      t += s[i*size, size]+"\n"
    end

    "-----BEGIN OpenVPN Static key V1-----\n" + t + "-----END OpenVPN Static key V1-----"
  end

  def create_openvpn_client_certificate(certifiable_entity, options = {})
    validity_time = options[:validity_time] || DEFAULT_CLIENT_CRT_VALIDITY_TIME
    key_length = options[:key_length] || DEFAULT_CERTIFICATE_KEY_LEN

    increment_serial()

    _key = OpenSSL::PKey::RSA.generate(key_length)

    issuer = OpenSSL::X509::Name.parse(self.dn)

    _dn = "#{self.dn_prefix}/CN=#{certifiable_entity.identifier}"

    ef = OpenSSL::X509::ExtensionFactory.new

    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = self.serial
    cert.subject = OpenSSL::X509::Name.parse(_dn)
    cert.issuer = issuer
    cert.public_key = _key.public_key
    cert.not_before = Time.now
    cert.not_after = cert.not_before + validity_time

    ef.subject_certificate = cert
    ef.issuer_certificate = OpenSSL::X509::Certificate.new(self.x509_certificate.certificate)

    Ca::CLIENT_CERT_EXTENSIONS.each do |extension|
      cert.add_extension(ef.create_ext_from_string(extension))
    end

    cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash"))
    cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always,issuer:always"))

    cert.sign(OpenSSL::PKey::RSA.new(self.x509_certificate.key), OpenSSL::Digest::SHA1.new)

    self.x509_certificates.create(
        :dn => _dn,
        :ca => self,
        :certifiable => certifiable_entity,
        :certificate => cert.to_pem,
        :key => _key.to_pem
    )

  end

  def create_openvpn_server_certificate(certifiable_entity, options = {})
    validity_time = options[:validity_time] || DEFAULT_SERVER_CRT_VALIDITY_TIME
    key_length = options[:key_length] || DEFAULT_CERTIFICATE_KEY_LEN

    increment_serial()

    _key = OpenSSL::PKey::RSA.generate(key_length)

    issuer = OpenSSL::X509::Name.parse(self.dn)

    _dn = "#{self.dn_prefix}/CN=#{certifiable_entity.identifier}"

    ef = OpenSSL::X509::ExtensionFactory.new

    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = self.serial
    cert.subject = OpenSSL::X509::Name.parse(_dn)
    cert.issuer = issuer
    cert.public_key = _key.public_key
    cert.not_before = Time.now
    cert.not_after = cert.not_before + validity_time

    ef.subject_certificate = cert
    ef.issuer_certificate = OpenSSL::X509::Certificate.new(self.x509_certificate.certificate)

    Ca::SERVER_CERT_EXTENSIONS.each do |extension|
      cert.add_extension(ef.create_ext_from_string(extension))
    end

    cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash"))
    cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always,issuer:always"))

    cert.sign(OpenSSL::PKey::RSA.new(self.x509_certificate.key), OpenSSL::Digest::SHA1.new)

    self.x509_certificates.create(
        :dn => _dn,
        :ca => self,
        :certifiable => certifiable_entity,
        :certificate => cert.to_pem,
        :key => _key.to_pem
    )

  end

  def revoke_certificate!(x509_certificate, options = {})
    reason_code = options[:reason_code] || 1 # Actually Key Compromise

    if x509_certificate.id == self.x509_certificate.id
      raise("BUG: can't revoke my own certificate!")
    end

    cert = OpenSSL::X509::Certificate.new(x509_certificate.certificate)
    ca_cert = OpenSSL::X509::Certificate.new(self.x509_certificate.certificate)

    now = Time.now

    if self.crl_list.nil?
      crl_list = OpenSSL::X509::CRL.new()
    else
      crl_list = OpenSSL::X509::CRL.new(self.crl_list)
    end

    crl_list.issuer = ca_cert.issuer
    crl_list.version = 3
    crl_list.last_update = crl_list.next_update
    crl_list.next_update = now

    revoked = OpenSSL::X509::Revoked.new
    revoked.serial = cert.serial
    revoked.time = now

    enum = OpenSSL::ASN1::Enumerated(reason_code)
    ext = OpenSSL::X509::Extension.new("CRLReason", enum)

    revoked.add_extension(ext)
    crl_list.add_revoked(revoked)

    # Sign the crl
    crl_list.sign(OpenSSL::PKey::RSA.new(self.x509_certificate.key), OpenSSL::Digest::SHA1.new)

    self.crl_list = crl_list.to_pem
    self.save!

    x509_certificate.revoked = true

    x509_certificate.save!

    x509_certificate
  end

  def renew_certificate!(x509_certificate, options = {})
    validity_time = options[:validity_time]
    if options[:validity_time].nil?
      if x509_certificate.belongs_to_ca?
        validity_time = DEFAULT_CA_CRT_VALIDITY_TIME
      elsif x509_certificate.belongs_to_vpn_server?
        validity_time = DEFAULT_SERVER_CRT_VALIDITY_TIME
      else
        validity_time = DEFAULT_CLIENT_CRT_VALIDITY_TIME 
      end
    end

    cert = OpenSSL::X509::Certificate.new(x509_certificate.certificate)
    cert.not_before = Time.now
    cert.not_after = cert.not_before + validity_time

    cert.sign(OpenSSL::PKey::RSA.new(self.x509_certificate.key), OpenSSL::Digest::SHA1.new)
    x509_certificate.certificate = cert.to_pem

    x509_certificate.save!

    x509_certificate
  end

  def reissue_certificate!(x509_certificate, options = {})

    if x509_certificate.id == self.x509_certificate.id
      raise("BUG: can't reissue my own certificate!")
    end

    validity_time = options[:validity_time]
    if options[:validity_time].nil?
      if x509_certificate.belongs_to_ca?
        validity_time = DEFAULT_CA_CRT_VALIDITY_TIME
      elsif x509_certificate.belongs_to_vpn_server?
        validity_time = DEFAULT_SERVER_CRT_VALIDITY_TIME
      else
        validity_time = DEFAULT_CLIENT_CRT_VALIDITY_TIME 
      end
    end

    key_length = options[:key_length] || DEFAULT_CERTIFICATE_KEY_LEN

    increment_serial()

    cert = OpenSSL::X509::Certificate.new(x509_certificate.certificate)
    cert.serial = self.serial
    cert.not_before = Time.now
    cert.not_after = cert.not_before + validity_time

    # Generate a new key
    _key = OpenSSL::PKey::RSA.generate(key_length)
    cert.public_key = _key.public_key

    cert.sign(OpenSSL::PKey::RSA.new(self.x509_certificate.key), OpenSSL::Digest::SHA1.new)

    x509_certificate.certificate = cert.to_pem
    x509_certificate.key = _key.to_pem

    x509_certificate.revoked = false

    x509_certificate.save!

    x509_certificate
  end

  private

  def increment_serial
    self.lock!
    self.serial += 1
    self.save
  end

end
