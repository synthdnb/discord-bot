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


def rand_uma
    weight = {
        "A" => 100,
        "B" => 10,
        "C" => 5,
        "D" => 4,
        "E" => 3,
        "F" => 2,
        "G" => 1,
    }

    uma = {
        "맥퀸"  => %w(A E G F A A B A D F),
        "루돌프" => %w(A G E C A A B A A C),
        "바병스" => %w(A G F C A A G A A C),
        "스즈카" => %w(A G D A A E A C E G),
        "마루젠" => %w(A D B A B C A E G G),
        "오구리" => %w(A B E A A B F A A D),
        "고루시" => %w(A G G C A A G B B A),
        "보드카" => %w(A G F A A F C B A F),
        "다이와" => %w(A G F A A B A A E G),
        "그라스" => %w(A G G A B A F A A F),
        "엘콘파" => %w(A B F A A B E A A C),
        "그루브" => %w(A G C B A E D A A G),
        "대두"  => %w(A F F C A A E A B E),
        "마야노" => %w(A E D D A A A A B B),
        "라이스" => %w(A G E C A A B A C G),
        "타키온" => %w(A G G D A B E A B F),
        "위닝티켓" => %w(A G G F A B G B A G),
        "박신오" => %w(A G A B G G A A F G),
        "슈퍼크릭" => %w(A G G G A A D A B G),
        "우라라" => %w(G A A B G G G G A B),
        "마치카네후쿠키타루" => %w(A F F C A A G B A F),
        "네이쳐" => %w(A G G C A A F B A D),
        "킹" => %w(A G A B B C G B A D),
        "라이언" => %w(A G E C A B F A A F),
        "테이오" => %w(A G F E A B D A C E),
        "타이키" => %w(A B A A E G C A E G),
        "오페라" => %w(A E G E A A C A A G),
        "부르봉" => %w(A G C B A B A E G G)
    }
    stat_names = %w(잔디 더트 단거리 마일 중거리 장거리 도주 선행 사시 추입)

    uma_key = uma.keys.sample
    weights = uma[uma_key].map{|x| weight[x]}
    if weights[0] == 100
        weights[0] = 0
    end
    if weights[1] == 100
        weights[1] = 0
    end
    ps = weights.map { |w| (Float w) / weights.reduce(:+) }
    loaded_die = stat_names.zip(ps).to_h
    stat = loaded_die.max_by { |_, weight| rand ** (1.0 / weight) }.first

    return "#{stat} #{uma_key}"
end

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
    when "뭐키우지"
        event << rand_uma
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
