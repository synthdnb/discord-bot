#!/usr/bin/env ruby
require 'discordrb'
require 'redis'

unless ENV['PRODUCTION']
    require 'pry'
    require 'dotenv'
    Dotenv.load
end

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

def redis
    @redis ||= Redis.new(host: "redis")
end

def client
    @client ||= Discordrb::Bot.new token: ENV['TOKEN'], client_id: ENV['CLIENT_ID']
end

Discordrb::LOGGER.mode = :debug

reserved = %w(등록 삭제 목록)

client.message(with_text: /\A!(\S+)(.*)/m) do |event|
    next unless event.server
    next unless /\A!(\S+)(.*)/m.match(event.message.content)
    cmd = $1
    content = $2.strip
    hkey = "#{event.server.id}-keywords"
    keywords = redis.hkeys(hkey)
    case cmd
    when "목록"
        event << keywords.sort.join(", ")
    when "등록"
        # next unless event.channel.type == 1
        data = {}

        if event.message.attachments.empty?
            next unless content.match /\A(\S+)(.*)/m
            data[:key] = $1
            data[:value] = $2.strip
        else
            content.match /\A(\S+)/
            data[:key] = $1.strip
            data[:value] = event.message.attachments.first.url
        end
        
        if reserved.include? data[:key]
            event << "예약된 키워드입니다"
            next
        end

        if data[:value]
            redis.hset(hkey, data[:key], data[:value])
            event << "키워드 '#{data[:key]}' 등록을 완료했습니다"
        else
            event << "내용을 입력해주세요"
        end
    when "삭제"
        # next unless event.channel.type == 1
        next unless content.match /\A(\S+)(.*)/m
        key = $1
        result = redis.hdel(hkey, key)
        if result == 1
            event << "키워드 '#{key}' 삭제를 완료했습니다"
        else
            event << "그런거 없는데수우"
        end
    else
        response = redis.hget(hkey, cmd)
        if response
            event << response
        else
            targets = keywords.select{|x| x.include? cmd}
            case targets.length
            when 0
            when 1
                keyword = targets.first
                response = redis.hget(hkey, keyword)
                event << "!#{keyword}\n#{response}"
            else
                event << targets.sort.join(", ")
            end
        end        
    end
end

client.run
