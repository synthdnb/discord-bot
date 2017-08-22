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

reserved = %w(공지 등록 삭제 목록)

client.message(with_text: /\A!(\S+)(.*)/m) do |event|
    next unless /\A!(\S+)(.*)/m.match(event.message.content)
    cmd = $1
    content = $2.strip
    keywords = redis.hkeys "keywords"
    case cmd
    when "목록"
        event << keywords.sort.join(", ")
    when "등록"
        next unless event.channel.type == 1
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
            redis.hset "keywords", data[:key], data[:value]
            event << "키워드 '#{data[:key]}' 등록을 완료했습니다"
        else
            event << "내용을 입력해주세요"
        end
    when "삭제"
        next unless event.channel.type == 1
        next unless content.match /\A(\S+)(.*)/m
        key = $1
        redis.hdel "keywords", key
        event << "키워드 '#{key}' 삭제를 완료했습니다"
    when *keywords
        response = redis.hget "keywords", cmd
        event << response
    else
        event << "알 수 없는 명령어입니다"
    end
end

client.run
