local function enable_channel(chat_id)
    local lang = get_lang(chat_id)

    if not config.disabled_channels then
        config.disabled_channels = { }
    end

    if config.disabled_channels[chat_id] == nil then
        return langs[lang].botOn
    end

    config.disabled_channels[chat_id] = false

    save_config()
    return langs[lang].botOn
end

local function disable_channel(chat_id)
    local lang = get_lang(chat_id)

    if not config.disabled_channels then
        config.disabled_channels = { }
    end

    config.disabled_channels[chat_id] = true

    save_config()
    return langs[lang].botOff
end

local function run(msg, matches)
    if msg.chat.type == 'private' then
        if matches[1]:lower() == '/start' then
            redis_set_something('notice:' .. msg.from.id, 1)
            sendKeyboard(msg.chat.id, langs[msg.lang].startMessage, keyboard_langs('B'))
            mystat('/start' ..(matches[2] or ''):lower())
            if matches[2] then
                local copied_msg = clone_table(msg)
                msg = nil
                copied_msg.text = '/' .. matches[2]
                if msg_valid(copied_msg) then
                    copied_msg = pre_process_msg(copied_msg)
                    if copied_msg then
                        match_plugins(copied_msg)
                    end
                end
            end
            return
        end
        if matches[1]:lower() == 'del' then
            if msg.reply then
                if msg.reply_to_message.from.id == bot.id then
                    mystat('/del')
                    if not deleteMessage(msg.chat.id, msg.reply_to_message.message_id, true) then
                        return langs[msg.lang].cantDeleteMessage
                    end
                else
                    return langs[msg.lang].cantDeleteMessage
                end
            else
                return langs[msg.lang].needReply
            end
        end
        if matches[1]:lower() == 'delkeyboard' then
            if msg.reply then
                if msg.reply_to_message.from.id == bot.id then
                    if msg.reply_to_message.text then
                        mystat('/delkeyboard')
                        return editMessageReplyMarkup(msg.chat.id, msg.reply_to_message.message_id)
                    end
                else
                    return langs[msg.lang].cantDeleteMessage
                end
            else
                return langs[msg.lang].needReply
            end
        end
    end
    if matches[1]:lower() == 'off' then
        if matches[2] then
            if is_admin(msg) then
                mystat('/bot off <group_id>')
                return disable_channel(matches[2])
            else
                return langs[msg.lang].require_admin
            end
        else
            if msg.from.is_owner then
                mystat('/bot off')
                return disable_channel(msg.chat.id)
            else
                return langs[msg.lang].require_owner
            end
        end
    elseif matches[1]:lower() == 'on' then
        if matches[2] then
            if is_admin(msg) then
                mystat('/bot on <group_id>')
                return enable_channel(matches[2])
            else
                return langs[msg.lang].require_admin
            end
        else
            if msg.from.is_owner then
                mystat('/bot on')
                return enable_channel(msg.chat.id)
            else
                return langs[msg.lang].require_owner
            end
        end
    end
end

return {
    description = "BOT",
    patterns =
    {
        "^(/[Ss][Tt][Aa][Rr][Tt])$",
        "^(/[Ss][Tt][Aa][Rr][Tt]) (.*)$",
        "^[#!/]([Dd][Ee][Ll])$",
        "^[#!/]([Dd][Ee][Ll][Kk][Ee][Yy][Bb][Oo][Aa][Rr][Dd])$",
        "^[#!/][Bb][Oo][Tt] ([Oo][Nn])$",
        "^[#!/][Bb][Oo][Tt] ([Oo][Ff][Ff])$",
        "^[#!/][Bb][Oo][Tt] ([Oo][Nn]) (%-?%d+)$",
        "^[#!/][Bb][Oo][Tt] ([Oo][Ff][Ff]) (%-?%d+)$",
        -- bot
        "^[Ss][Aa][Ss][Hh][Aa] ([Oo][Nn])$",
        "^[Ss][Aa][Ss][Hh][Aa] ([Oo][Ff][Ff])$",
        "^[Ss][Aa][Ss][Hh][Aa] ([Oo][Nn]) (%-?%d+)$",
        "^[Ss][Aa][Ss][Hh][Aa] ([Oo][Ff][Ff]) (%-?%d+)$",
    },
    run = run,
    min_rank = 1,
    syntax =
    {
        "USER",
        "/start[@AISashaBot]",
        "/del {reply}",
        "/delkeyboard {reply}",
        "OWNER",
        "/bot|sasha on|off",
        "ADMIN",
        "/bot|sasha on|off [{group_id}]",
    }
}