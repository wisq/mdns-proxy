#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'
require 'resolv'
require 'socket'
require 'etc'

BIND_ADDRESS = '127.0.0.1'  # you probably want to bind to your LAN address
BIND_PORT    = 53           # ports lower than 1024 require superuser privileges

PROXY_DOMAIN  = 'vpn'    # accept queries for *.vpn
LOOKUP_DOMAIN = 'local'  # proxy them as queries for *.local

module Server
  UDP_TRUNCATION_SIZE = 512

  def initialize
    set_comm_inactivity_timeout 15
  end

  def receive_data(data)
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    query = Resolv::DNS::Message::decode(data)
    response = Response.new(self, query, "#{ip}:#{port}")
  end

  def respond(answer)
    data = answer.encode

    if (data.size > UDP_TRUNCATION_SIZE)
      answer.tc = 1
      data = answer.encode[0, UDP_TRUNCATION_SIZE]
    end

    send_data(data)
  end
end

class Response
  def initialize(server, query, peer)
    @server = server
    @peer   = peer

    # Setup answer
    @answer = Resolv::DNS::Message::new(query.id)
    @answer.qr = 1                 # 0 = Query, 1 = Response
    @answer.opcode = query.opcode  # Type of Query; copy from query
    @answer.aa = 1                 # Is this an authoritative response: 0 = No, 1 = Yes
    @answer.rd = query.rd          # Is Recursion Desired, copied from query
    @answer.ra = 0                 # Does name server support recursion: 0 = No, 1 = Yes
    @answer.rcode = 0              # Response code: 0 = No errors

    @pending = []
    query.each_question do |question, resource_class|    # There may be multiple questions per query
      puts "Received query for #{question.to_s} from #{@peer}"
      next unless question.to_s =~ /^([^\.]+)\.([^\.]+)\.?$/
      name, domain = $1, $2
      next unless domain == PROXY_DOMAIN

      @pending << Resolver.new(self, name, domain)
    end

    ping
  end

  def ping
    send_answer if ready?
  end

  def ready?
    @pending.all? {|r| r.ready?}
  end

  def send_answer
    @pending.each do |resolver|
      if resolver.success?
        resource = Resolv::DNS::Resource::IN::A.new(resolver.answer_ip)
        @answer.add_answer(resolver.answer_name + '.', 300, resource)
        puts "Sending #{resolver.answer_name} = #{resolver.answer_ip} to #{@peer}"
      else
        @answer.rcode = 3 # nxdomain
        puts "Sending NXDOMAIN to #{@peer}"
      end
    end

    @server.respond(@answer)
  end
end

module ProcessWatcher
  def initialize(resolv)
    @resolv = resolv
  end

  def process_exited
    @resolv.ping
  end
end

class Resolver
  attr_reader :ready, :success, :answer_name, :answer_ip
  alias_method :ready?,   :ready
  alias_method :success?, :success

  def initialize(response, name, domain)
    @response = response
    @answer_name = "#{name}.#{domain}"
    @ready = false

    EventMachine.system('avahi-resolve', '-4n', "#{name}.#{LOOKUP_DOMAIN}") do |output, status|
      line       = output.lines.first
      @answer_ip = line.chomp.split("\t").last if line
      @success   = !line.nil?

      @ready = true
      @response.ping
    end
  end
end

def drop_privs(user, group)
  uid = Etc.getpwnam(user).uid
  gid = Etc.getgrnam(group).gid

  Process::Sys.setgid(gid)
  Process::Sys.setuid(uid)
end

EventMachine.run do
  EventMachine.open_datagram_socket(BIND_ADDRESS, BIND_PORT, Server)
  drop_privs('nobody', 'nogroup') if Process::Sys.getuid == 0
end
