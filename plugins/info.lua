﻿local function is_here(chat_id, user_id)
    local lang = get_lang(chat_id)
    local chat_member = getChatMember(chat_id, user_id)
    if type(chat_member) == 'table' then
        if chat_member.result then
            chat_member = chat_member.result
            if chat_member.status == 'creator' or chat_member.status == 'administrator' or chat_member.status == 'member' then
                return langs[lang].ishereYes
            else
                return langs[lang].ishereNo
            end
        end
    end
end

local function get_reverse_rank(chat_id, user_id, check_local)
    local lang = get_lang(chat_id)
    local rank = get_rank(user_id, chat_id, check_local)
    return langs[lang].rank .. reverse_rank_table[rank + 1]
end

local function get_object_info(obj, chat_id)
    local lang = get_lang(chat_id)
    if obj then
        local text = langs[lang].infoWord
        if obj.type == 'bot' or obj.is_bot then
            text = text .. langs[lang].chatType .. langs[lang].botWord
            if obj.first_name then
                if obj.first_name == '' then
                    if database[tostring(obj.id)] then
                        return serpent.block(database[tostring(obj.id)], { sortkeys = false, comment = false })
                    else
                        text = text .. '\n$Deleted Account$'
                    end
                else
                    text = text .. langs[lang].name .. obj.first_name
                end
            end
            if obj.last_name then
                text = text .. langs[lang].surname .. obj.last_name
            end
            if obj.username then
                text = text .. langs[lang].username .. '@' .. obj.username
            end
            text = text .. langs[lang].date .. os.date('%c')
            local otherinfo = langs[lang].otherInfo
            if obj.id ~= bot.id then
                local chat_member = getChatMember(chat_id, obj.id)
                if type(chat_member) == 'table' then
                    if chat_member.result then
                        chat_member = chat_member.result
                        if chat_member.status then
                            otherinfo = otherinfo .. chat_member.status:upper() .. ' '
                        end
                    end
                end
            end
            if isWhitelisted(id_to_cli(chat_id), obj.id) then
                otherinfo = otherinfo .. 'WHITELISTED '
            end
            if isWhitelistedGban(id_to_cli(chat_id), obj.id) then
                otherinfo = otherinfo .. 'GBANWHITELISTED '
            end
            if isGbanned(obj.id) then
                otherinfo = otherinfo .. 'GBANNED '
            end
            if isBanned(obj.id, chat_id) then
                otherinfo = otherinfo .. 'BANNED '
            end
            if isMutedUser(chat_id, obj.id) then
                otherinfo = otherinfo .. 'MUTED '
            end
            if string.match(getUserWarns(obj.id, chat_id), '%d+') then
                otherinfo = otherinfo .. string.match(getUserWarns(obj.id, chat_id), '%d+') .. ' WARN '
            end
            if otherinfo == langs[lang].otherInfo then
                otherinfo = otherinfo .. langs[lang].noOtherInfo
            end
            text = text .. otherinfo ..
            langs[lang].long_id .. obj.id
        elseif obj.type == 'private' or obj.type == 'user' then
            text = text .. langs[lang].chatType .. langs[lang].userWord
            if obj.first_name then
                if obj.first_name == '' then
                    if database[tostring(obj.id)] then
                        return serpent.block(database[tostring(obj.id)], { sortkeys = false, comment = false })
                    else
                        text = text .. '\n$Deleted Account$'
                    end
                else
                    text = text .. langs[lang].name .. obj.first_name
                end
            end
            if obj.last_name then
                text = text .. langs[lang].surname .. obj.last_name
            end
            if obj.username then
                text = text .. langs[lang].username .. '@' .. obj.username
            end
            local msgs = tonumber(redis:get('msgs:' .. obj.id .. ':' .. chat_id) or 0)
            text = text .. langs[lang].rank .. reverse_rank_table[get_rank(obj.id, chat_id, true) + 1] ..
            langs[lang].date .. os.date('%c') ..
            langs[lang].totalMessages .. msgs
            local otherinfo = langs[lang].otherInfo
            if obj.id ~= bot.id then
                local chat_member = getChatMember(chat_id, obj.id)
                if type(chat_member) == 'table' then
                    if chat_member.result then
                        chat_member = chat_member.result
                        if chat_member.status then
                            otherinfo = otherinfo .. chat_member.status:upper() .. ' '
                        end
                    end
                end
            end
            if isWhitelisted(id_to_cli(chat_id), obj.id) then
                otherinfo = otherinfo .. 'WHITELISTED '
            end
            if isWhitelistedGban(id_to_cli(chat_id), obj.id) then
                otherinfo = otherinfo .. 'GBANWHITELISTED '
            end
            if isGbanned(obj.id) then
                otherinfo = otherinfo .. 'GBANNED '
            end
            if isBanned(obj.id, chat_id) then
                otherinfo = otherinfo .. 'BANNED '
            end
            if isMutedUser(chat_id, obj.id) then
                otherinfo = otherinfo .. 'MUTED '
            end
            if isBlocked(obj.id) then
                otherinfo = otherinfo .. 'PM BLOCKED '
            end
            if string.match(getUserWarns(obj.id, chat_id), '%d+') then
                otherinfo = otherinfo .. string.match(getUserWarns(obj.id, chat_id), '%d+') .. ' WARN '
            end
            if otherinfo == langs[lang].otherInfo then
                otherinfo = otherinfo .. langs[lang].noOtherInfo
            end
            text = text .. otherinfo ..
            langs[lang].long_id .. obj.id
        elseif obj.type == 'group' then
            text = text .. langs[lang].chatType .. langs[lang].groupWord
            if obj.title then
                text = text .. langs[lang].groupName .. obj.title
            end
            text = text .. langs[lang].date .. os.date('%c') ..
            langs[lang].long_id .. obj.id
        elseif obj.type == 'supergroup' then
            text = text .. langs[lang].chatType .. langs[lang].supergroupWord
            if obj.title then
                text = text .. langs[lang].supergroupName .. obj.title
            end
            if obj.username then
                text = text .. langs[lang].username .. '@' .. obj.username
            end
            text = text .. langs[lang].date .. os.date('%c') ..
            langs[lang].long_id .. obj.id
        elseif obj.type == 'channel' then
            text = text .. langs[lang].chatType .. langs[lang].channelWord
            if obj.title then
                text = text .. langs[lang].channelName .. obj.title
            end
            if obj.username then
                text = text .. langs[lang].username .. '@' .. obj.username
            end
            text = text .. langs[lang].date .. os.date('%c') ..
            langs[lang].long_id .. obj.id
        else
            return langs[lang].peerTypeUnknown
        end
        return text
    else
        return langs[lang].noObject
    end
end

local function get_object_info_keyboard(obj, chat_id)
    local lang = get_lang(chat_id)
    if obj then
        local keyboard = { }
        keyboard.inline_keyboard = { }
        local row = 1
        local column = 1
        keyboard.inline_keyboard[row] = { }
        local text = langs[lang].infoWord
        if obj.type == 'bot' or obj.is_bot then
            text = text .. langs[lang].chatType .. langs[lang].botWord
            if obj.first_name then
                if obj.first_name == '' then
                    text = text .. '\n$Deleted Account$'
                else
                    text = text .. langs[lang].name .. obj.first_name
                end
            end
            if obj.last_name then
                text = text .. langs[lang].surname .. obj.last_name
            end
            if obj.username then
                text = text .. langs[lang].username .. '@' .. obj.username
            end
            text = text .. langs[lang].date .. os.date('%c')
            local otherinfo = langs[lang].otherInfo
            if obj.id ~= bot.id then
                local chat_member = getChatMember(chat_id, obj.id)
                if type(chat_member) == 'table' then
                    if chat_member.result then
                        chat_member = chat_member.result
                        if chat_member.status then
                            otherinfo = otherinfo .. chat_member.status:upper() .. ' '
                        end
                    end
                end
            end
            if isWhitelisted(id_to_cli(chat_id), obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ WHITELISTED', callback_data = 'infoWHITELIST' .. var .. chat_id }
                otherinfo = otherinfo .. 'WHITELISTED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ WHITELISTED' .. reverseAdjustSettingType(var), callback_data = 'infoWHITELIST' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isWhitelistedGban(id_to_cli(chat_id), obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ GBANWHITELISTED', callback_data = 'infoGBANWHITELIST' .. var .. chat_id }
                otherinfo = otherinfo .. 'GBANWHITELISTED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ GBANWHITELISTED' .. reverseAdjustSettingType(var), callback_data = 'infoGBANWHITELIST' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isGbanned(obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ GBANNED', callback_data = 'infoUNGBAN' .. var .. chat_id }
                otherinfo = otherinfo .. 'GBANNED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ GBANNED' .. reverseAdjustSettingType(var), callback_data = 'infoGBAN' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isBanned(obj.id, chat_id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ BANNED', callback_data = 'infoUNBAN' .. var .. chat_id }
                otherinfo = otherinfo .. 'BANNED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ BANNED' .. reverseAdjustSettingType(var), callback_data = 'infoBAN' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isMutedUser(chat_id, obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ MUTED', callback_data = 'infoMUTEUSER' .. var .. chat_id }
                otherinfo = otherinfo .. 'MUTED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ MUTED' .. reverseAdjustSettingType(var), callback_data = 'infoMUTEUSER' .. var .. chat_id }
            end
            if string.match(getUserWarns(obj.id, chat_id), '%d+') then
                row = row + 1
                column = 1
                keyboard.inline_keyboard[row] = { }
                -- start warn part
                keyboard.inline_keyboard[row][column] = { text = '-', callback_data = 'infoWARNSMINUS' .. data[tostring(chat_id)].settings.warn_max .. chat_id }
                column = column + 1
                keyboard.inline_keyboard[row][column] = { text = string.match(getUserWarns(obj.id, chat_id), '%d+'), callback_data = 'infoWARNS' .. chat_id }
                column = column + 1
                keyboard.inline_keyboard[row][column] = { text = '+', callback_data = 'infoWARNSPLUS' .. data[tostring(chat_id)].settings.warn_max .. chat_id }
                -- end warn part
                otherinfo = otherinfo .. string.match(getUserWarns(obj.id, chat_id), '%d+') .. ' WARN '
            end
            if otherinfo == langs[lang].otherInfo then
                otherinfo = otherinfo .. langs[lang].noOtherInfo
            end
            text = text .. otherinfo ..
            langs[lang].long_id .. obj.id
        elseif obj.type == 'private' or obj.type == 'user' then
            text = text .. langs[lang].chatType .. langs[lang].userWord
            if obj.first_name then
                if obj.first_name == '' then
                    if database[tostring(obj.id)] then
                        return serpent.block(database[tostring(obj.id)], { sortkeys = false, comment = false })
                    else
                        text = text .. '\n$Deleted Account$'
                    end
                else
                    text = text .. langs[lang].name .. obj.first_name
                end
            end
            if obj.last_name then
                text = text .. langs[lang].surname .. obj.last_name
            end
            if obj.username then
                text = text .. langs[lang].username .. '@' .. obj.username
            end
            local msgs = tonumber(redis:get('msgs:' .. obj.id .. ':' .. chat_id) or 0)
            text = text .. langs[lang].rank .. reverse_rank_table[get_rank(obj.id, chat_id, true) + 1] ..
            langs[lang].date .. os.date('%c') ..
            langs[lang].totalMessages .. msgs
            local otherinfo = langs[lang].otherInfo
            if obj.id ~= bot.id then
                local chat_member = getChatMember(chat_id, obj.id)
                if type(chat_member) == 'table' then
                    if chat_member.result then
                        chat_member = chat_member.result
                        if chat_member.status then
                            otherinfo = otherinfo .. chat_member.status:upper() .. ' '
                        end
                    end
                end
            end
            if isWhitelisted(id_to_cli(chat_id), obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ WHITELISTED', callback_data = 'infoWHITELIST' .. var .. chat_id }
                otherinfo = otherinfo .. 'WHITELISTED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ WHITELISTED' .. reverseAdjustSettingType(var), callback_data = 'infoWHITELIST' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isWhitelistedGban(id_to_cli(chat_id), obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ GBANWHITELISTED', callback_data = 'infoGBANWHITELIST' .. var .. chat_id }
                otherinfo = otherinfo .. 'GBANWHITELISTED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ GBANWHITELISTED' .. reverseAdjustSettingType(var), callback_data = 'infoGBANWHITELIST' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isGbanned(obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ GBANNED', callback_data = 'infoUNGBAN' .. var .. chat_id }
                otherinfo = otherinfo .. 'GBANNED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ GBANNED' .. reverseAdjustSettingType(var), callback_data = 'infoGBAN' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isBanned(obj.id, chat_id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ BANNED', callback_data = 'infoUNBAN' .. var .. chat_id }
                otherinfo = otherinfo .. 'BANNED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ BANNED' .. reverseAdjustSettingType(var), callback_data = 'infoBAN' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isMutedUser(chat_id, obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ MUTED', callback_data = 'infoMUTEUSER' .. var .. chat_id }
                otherinfo = otherinfo .. 'MUTED '
            else
                keyboard.inline_keyboard[row][column] = { text = '☑️ MUTED' .. reverseAdjustSettingType(var), callback_data = 'infoMUTEUSER' .. var .. chat_id }
            end
            row = row + 1
            column = 1
            keyboard.inline_keyboard[row] = { }
            if isBlocked(obj.id) then
                keyboard.inline_keyboard[row][column] = { text = '✅ PM BLOCKED', callback_data = 'infoPMUNBLOCK' .. var .. chat_id }
                otherinfo = otherinfo .. 'PM BLOCKED '
            else
                keyboard.inline_keyboard[row][column] = { text = '✅ PM BLOCKED', callback_data = 'infoPMBLOCK' .. var .. chat_id }
            end
            if string.match(getUserWarns(obj.id, chat_id), '%d+') then
                row = row + 1
                column = 1
                keyboard.inline_keyboard[row] = { }
                keyboard.inline_keyboard[row][column] = { text = '-', callback_data = 'infoWARNSMINUS' .. data[tostring(chat_id)].settings.warn_max .. chat_id }
                column = column + 1
                keyboard.inline_keyboard[row][column] = { text = 'WARN ' .. string.match(getUserWarns(obj.id, chat_id), '%d+'), callback_data = 'infoWARNS' .. chat_id }
                column = column + 1
                keyboard.inline_keyboard[row][column] = { text = '+', callback_data = 'infoWARNSPLUS' .. data[tostring(chat_id)].settings.warn_max .. chat_id }
                otherinfo = otherinfo .. string.match(getUserWarns(obj.id, chat_id), '%d+') .. ' WARN '
            end
            if otherinfo == langs[lang].otherInfo then
                otherinfo = otherinfo .. langs[lang].noOtherInfo
            end
            text = text .. otherinfo ..
            langs[lang].long_id .. obj.id
        elseif obj.type == 'group' then
            text = text .. langs[lang].chatType .. langs[lang].groupWord
            if obj.title then
                text = text .. langs[lang].groupName .. obj.title
            end
            text = text .. langs[lang].date .. os.date('%c') ..
            langs[lang].long_id .. obj.id
        elseif obj.type == 'supergroup' then
            text = text .. langs[lang].chatType .. langs[lang].supergroupWord
            if obj.title then
                text = text .. langs[lang].supergroupName .. obj.title
            end
            if obj.username then
                text = text .. langs[lang].username .. '@' .. obj.username
            end
            text = text .. langs[lang].date .. os.date('%c') ..
            langs[lang].long_id .. obj.id
        elseif obj.type == 'channel' then
            text = text .. langs[lang].chatType .. langs[lang].channelWord
            if obj.title then
                text = text .. langs[lang].channelName .. obj.title
            end
            if obj.username then
                text = text .. langs[lang].username .. '@' .. obj.username
            end
            text = text .. langs[lang].date .. os.date('%c') ..
            langs[lang].long_id .. obj.id
        else
            return langs[lang].peerTypeUnknown
        end
        row = row + 1
        column = 1
        keyboard.inline_keyboard[row] = { }
        keyboard.inline_keyboard[row][column] = { text = langs[get_lang(chat_id)].updateKeyboard, callback_data = 'infoBACK' .. chat_id }
        column = column + 1
        keyboard.inline_keyboard[row][column] = { text = langs[get_lang(chat_id)].deleteKeyboard, callback_data = 'infoDELETE' }
        return text
    end
end

local function run(msg, matches)
    if matches[1]:lower() == 'id' then
        mystat('/id')
        if msg.reply then
            if msg.from.is_mod then
                if matches[2] then
                    if matches[2]:lower() == 'from' then
                        if msg.reply_to_message.forward then
                            if msg.reply_to_message.forward_from then
                                return msg.reply_to_message.forward_from.id
                            else
                                return msg.reply_to_message.forward_from_chat.id
                            end
                        else
                            return langs[msg.lang].errorNoForward
                        end
                    else
                        return msg.reply_to_message.from.id
                    end
                else
                    if msg.reply_to_message.service then
                        if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                            local text = msg.reply_to_message.adder.id .. '\n'
                            for k, v in pairs(msg.reply_to_message.added) do
                                text = text .. v.id .. '\n'
                            end
                            return text
                        elseif msg.reply_to_message.service_type == 'chat_add_user_link' then
                            return msg.reply_to_message.from.id
                        elseif msg.reply_to_message.service_type == 'chat_del_user' then
                            return msg.reply_to_message.remover.id .. '\n' .. msg.reply_to_message.removed.id
                        elseif msg.reply_to_message.service_type == 'chat_del_user_leave' then
                            return msg.reply_to_message.removed.id
                        else
                            return msg.reply_to_message.from.id
                        end
                    else
                        return msg.reply_to_message.from.id
                    end
                end
            else
                return langs[msg.lang].require_mod
            end
        elseif matches[2] and matches[2] ~= '' then
            if msg.from.is_mod then
                if msg.entities then
                    for k, v in pairs(msg.entities) do
                        -- check if there's a text_mention
                        if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                            if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                local obj = getChat(msg.entities[k].user.id)
                                if obj then
                                    return obj.id
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                    end
                end
                local obj = getChat('@' ..(string.match(matches[2], '^[^%s]+'):gsub('@', '') or ''))
                if obj then
                    return obj.id
                else
                    return langs[msg.lang].noObject
                end
            else
                return langs[msg.lang].require_mod
            end
        else
            return msg.from.id .. '\n' .. msg.chat.id
        end
    end
    if matches[1]:lower() == 'username' then
        mystat('/username')
        if msg.reply then
            if msg.from.is_mod then
                if matches[2] then
                    if matches[2]:lower() == 'from' then
                        if msg.reply_to_message.forward then
                            if msg.reply_to_message.forward_from then
                                return msg.reply_to_message.forward_from.username or('NOUSER ' .. msg.reply_to_message.forward_from.first_name .. ' ' ..(msg.reply_to_message.forward_from.last_name or ''))
                            else
                                return msg.reply_to_message.forward_from_chat.username or 'NOUSER ' .. msg.reply_to_message.forward_from_chat.title
                            end
                        else
                            return langs[msg.lang].errorNoForward
                        end
                    else
                        return msg.reply_to_message.from.username or('NOUSER ' .. msg.reply_to_message.from.first_name .. ' ' ..(msg.reply_to_message.from.last_name or ''))
                    end
                else
                    if msg.reply_to_message.service then
                        if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                            local text =(msg.reply_to_message.adder.username or('NOUSER ' .. msg.reply_to_message.adder.first_name .. ' ' ..(msg.reply_to_message.adder.last_name or ''))) .. '\n'
                            for k, v in pairs(msg.reply_to_message.added) do
                                text = text ..(v.username or('NOUSER ' .. v.first_name .. ' ' ..(v.last_name or ''))) .. '\n'
                            end
                            return text
                        elseif msg.reply_to_message.service_type == 'chat_add_user_link' then
                            return msg.reply_to_message.from.username or('NOUSER ' .. msg.reply_to_message.from.first_name .. ' ' ..(msg.reply_to_message.from.last_name or ''))
                        elseif msg.reply_to_message.service_type == 'chat_del_user' then
                            return(msg.reply_to_message.remover.username or('NOUSER ' .. msg.reply_to_message.remover.first_name .. ' ' ..(msg.reply_to_message.remover.last_name or ''))) .. '\n' ..(msg.reply_to_message.removed.username or('NOUSER ' .. msg.reply_to_message.removed.first_name .. ' ' ..(msg.reply_to_message.removed.last_name or '')))
                        elseif msg.reply_to_message.service_type == 'chat_del_user_leave' then
                            return msg.reply_to_message.removed.username or('NOUSER ' .. msg.reply_to_message.remover.first_name .. ' ' ..(msg.reply_to_message.remover.last_name or ''))
                        else
                            return msg.reply_to_message.from.username or('NOUSER ' .. msg.reply_to_message.from.first_name .. ' ' ..(msg.reply_to_message.from.last_name or ''))
                        end
                    else
                        return msg.reply_to_message.from.username or('NOUSER ' .. msg.reply_to_message.from.first_name .. ' ' ..(msg.reply_to_message.from.last_name or ''))
                    end
                end
            else
                return langs[msg.lang].require_mod
            end
        elseif matches[2] and matches[2] ~= '' then
            if msg.from.is_mod then
                if msg.entities then
                    for k, v in pairs(msg.entities) do
                        -- check if there's a text_mention
                        if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                            if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                local obj = getChat(msg.entities[k].user.id)
                                if obj then
                                    return obj.id
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                    end
                end
                local obj = getChat(matches[2])
                if obj then
                    return obj.username or('NOUSER ' ..(obj.first_name or obj.title) .. ' ' ..(obj.last_name or ''))
                else
                    return langs[msg.lang].noObject
                end
            else
                return langs[msg.lang].require_mod
            end
        else
            return(msg.from.username or('NOUSER ' .. msg.from.first_name .. ' ' ..(msg.from.last_name or ''))) .. '\n' ..(msg.chat.username or('NOUSER ' .. msg.chat.title))
        end
    end
    if matches[1]:lower() == 'getrank' then
        mystat('/getrank')
        if msg.reply then
            if matches[2] then
                if matches[2]:lower() == 'from' then
                    if msg.reply_to_message.forward then
                        if msg.reply_to_message.forward_from then
                            return get_reverse_rank(msg.chat.id, msg.reply_to_message.forward_from.id, true)
                        else
                            return langs[msg.lang].cantDoThisToChat
                        end
                    else
                        return langs[msg.lang].errorNoForward
                    end
                else
                    return get_reverse_rank(msg.chat.id, msg.reply_to_message.from.id, true)
                end
            else
                return get_reverse_rank(msg.chat.id, msg.reply_to_message.from.id, true)
            end
        elseif matches[2] and matches[2] ~= '' then
            if msg.entities then
                for k, v in pairs(msg.entities) do
                    -- check if there's a text_mention
                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                            return get_reverse_rank(msg.chat.id, msg.entities[k].user.id, true)
                        end
                    end
                end
            end
            if string.match(matches[2], '^%d+$') then
                return get_reverse_rank(msg.chat.id, matches[2], true)
            else
                local obj_user = getChat('@' ..(string.match(matches[2], '^[^%s]+'):gsub('@', '') or ''))
                if obj_user then
                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                        return get_reverse_rank(msg.chat.id, obj_user.id, true)
                    end
                else
                    return langs[msg.lang].noObject
                end
            end
        else
            return get_reverse_rank(msg.chat.id, msg.from.id, true)
        end
    end
    if matches[1]:lower() == 'ishere' then
        mystat('/ishere')
        if msg.reply then
            if matches[2] then
                if matches[2]:lower() == 'from' then
                    if msg.reply_to_message.forward then
                        if msg.reply_to_message.forward_from then
                            return is_here(msg.chat.id, msg.reply_to_message.forward_from.id)
                        else
                            return langs[msg.lang].cantDoThisToChat
                        end
                    else
                        return langs[msg.lang].errorNoForward
                    end
                else
                    return is_here(msg.chat.id, msg.reply_to_message.from.id)
                end
            else
                return is_here(msg.chat.id, msg.reply_to_message.from.id)
            end
        elseif matches[2] and matches[2] ~= '' then
            if msg.entities then
                for k, v in pairs(msg.entities) do
                    -- check if there's a text_mention
                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                            return is_here(msg.chat.id, msg.entities[k].user.id)
                        end
                    end
                end
            end
            if string.match(matches[2], '^%d+$') then
                return is_here(msg.chat.id, tonumber(matches[2]))
            else
                local obj_user = getChat('@' ..(string.match(matches[2], '^[^%s]+'):gsub('@', '') or ''))
                if obj_user then
                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                        return is_here(msg.chat.id, obj_user.id)
                    end
                else
                    return langs[msg.lang].noObject
                end
            end
        end
    end
    if matches[1]:lower() == 'info' then
        mystat('/info')
        if msg.reply then
            if msg.from.is_mod then
                if matches[2] then
                    if matches[2]:lower() == 'from' then
                        if msg.reply_to_message.forward then
                            if msg.reply_to_message.forward_from then
                                return get_object_info(msg.reply_to_message.forward_from, msg.chat.id)
                            else
                                return get_object_info(msg.reply_to_message.forward_from_chat, msg.chat.id)
                            end
                        else
                            return langs[msg.lang].errorNoForward
                        end
                    end
                else
                    if msg.reply_to_message.service then
                        if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                            local text = get_object_info(msg.reply_to_message.adder, msg.chat.id) .. '\n'
                            for k, v in pairs(msg.reply_to_message.added) do
                                text = text .. get_object_info(v, msg.chat.id) .. '\n'
                            end
                            return text
                        elseif msg.reply_to_message.service_type == 'chat_add_user_link' then
                            return get_object_info(msg.reply_to_message.from, msg.chat.id)
                        elseif msg.reply_to_message.service_type == 'chat_del_user' then
                            return get_object_info(msg.reply_to_message.remover, msg.chat.id) .. '\n\n' .. get_object_info(msg.reply_to_message.removed, msg.chat.id)
                        elseif msg.reply_to_message.service_type == 'chat_del_user_leave' then
                            return get_object_info(msg.reply_to_message.removed, msg.chat.id)
                        else
                            return get_object_info(msg.reply_to_message.from, msg.chat.id)
                        end
                    else
                        return get_object_info(msg.reply_to_message.from, msg.chat.id)
                    end
                end
            else
                return langs[msg.lang].require_mod
            end
        elseif matches[2] and matches[2] ~= '' then
            if msg.from.is_mod then
                if msg.entities then
                    for k, v in pairs(msg.entities) do
                        -- check if there's a text_mention
                        if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                            if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                return get_object_info(msg.entities[k].user, msg.chat.id)
                            end
                        end
                    end
                end
                if string.match(matches[2], '^%-?%d+$') then
                    return get_object_info(getChat(matches[2]), msg.chat.id)
                else
                    return get_object_info(getChat('@' ..(string.match(matches[2], '^[^%s]+'):gsub('@', '') or '')), msg.chat.id)
                end
            else
                return langs[msg.lang].require_mod
            end
        else
            return get_object_info(msg.from, msg.chat.id) .. '\n\n' .. get_object_info(msg.bot or msg.chat, msg.chat.id)
        end
        return
    end
    if matches[1]:lower() == 'textualinfo' then
        mystat('/info')
        if msg.reply then
            if msg.from.is_mod then
                if matches[2] then
                    if matches[2]:lower() == 'from' then
                        if msg.reply_to_message.forward then
                            if msg.reply_to_message.forward_from then
                                return get_object_info(msg.reply_to_message.forward_from, msg.chat.id)
                            else
                                return get_object_info(msg.reply_to_message.forward_from_chat, msg.chat.id)
                            end
                        else
                            return langs[msg.lang].errorNoForward
                        end
                    end
                else
                    if msg.reply_to_message.service then
                        if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                            local text = get_object_info(msg.reply_to_message.adder, msg.chat.id) .. '\n'
                            for k, v in pairs(msg.reply_to_message.added) do
                                text = text .. get_object_info(v, msg.chat.id) .. '\n'
                            end
                            return text
                        elseif msg.reply_to_message.service_type == 'chat_add_user_link' then
                            return get_object_info(msg.reply_to_message.from, msg.chat.id)
                        elseif msg.reply_to_message.service_type == 'chat_del_user' then
                            return get_object_info(msg.reply_to_message.remover, msg.chat.id) .. '\n\n' .. get_object_info(msg.reply_to_message.removed, msg.chat.id)
                        elseif msg.reply_to_message.service_type == 'chat_del_user_leave' then
                            return get_object_info(msg.reply_to_message.removed, msg.chat.id)
                        else
                            return get_object_info(msg.reply_to_message.from, msg.chat.id)
                        end
                    else
                        return get_object_info(msg.reply_to_message.from, msg.chat.id)
                    end
                end
            else
                return langs[msg.lang].require_mod
            end
        elseif matches[2] and matches[2] ~= '' then
            if msg.from.is_mod then
                if msg.entities then
                    for k, v in pairs(msg.entities) do
                        -- check if there's a text_mention
                        if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                            if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                return get_object_info(msg.entities[k].user, msg.chat.id)
                            end
                        end
                    end
                end
                if string.match(matches[2], '^%-?%d+$') then
                    return get_object_info(getChat(matches[2]), msg.chat.id)
                else
                    return get_object_info(getChat('@' ..(string.match(matches[2], '^[^%s]+'):gsub('@', '') or '')), msg.chat.id)
                end
            else
                return langs[msg.lang].require_mod
            end
        else
            return get_object_info(msg.from, msg.chat.id) .. '\n\n' .. get_object_info(msg.bot or msg.chat, msg.chat.id)
        end
        return
    end
    --[[if matches[1]:lower() == 'who' or matches[1]:lower() == 'members' then
        if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
            if msg.from.is_mod then
                return langs[msg.lang].useAISasha
                mystat('/members')
                local participants = getChatParticipants(msg.chat.id)
                local text = langs[msg.lang].membersOf .. msg.chat.title .. ' ' .. msg.chat.id .. '\n'
                for k, v in pairsByKeys(participants) do
                    if v.user then
                        v = v.user
                        text = text ..(v.first_name or 'NONAME') ..(v.last_name or '') .. ' | @' ..(v.username or 'username') .. ' | ' .. v.id .. '\n'
                    end
                end
                -- remove rtl
                text = text:gsub("‮", "")
                return text
            else
                return langs[msg.lang].require_mod
            end
        end
    end]]
    if matches[1]:lower() == 'whoami' then
        mystat('/whoami')
        return get_object_info(msg.from, msg.chat.id)
    end
    if matches[1]:lower() == 'grouplink' and matches[2] then
        mystat('/grouplink')
        if is_admin(msg) then
            local group_link = data[tostring(matches[2])]['settings']['set_link']
            if not group_link then
                local link = exportChatInviteLink(matches[2])
                if link then
                    data[tostring(matches[2])]['settings']['set_link'] = link
                    save_data(config.moderation.data, data)
                    group_link = link
                else
                    return langs[msg.lang].noLinkAvailable
                end
            end
            local obj = getChat(matches[2])
            if type(obj) == 'table' then
                return obj.title .. '\n' .. group_link
            end
        else
            return langs[msg.lang].require_admin
        end
    end
end

local function pre_process(msg)
    if msg then
        if msg.chat.type == 'private' and msg.forward then
            if get_rank(msg.from.id, msg.chat.id, true) > 0 then
                -- if moderator in some group or higher
                if msg.forward_from then
                    sendMessage(msg.chat.id, get_object_info(msg.forward_from, msg.chat.id))
                end
                if msg.forward_from_chat then
                    sendMessage(msg.chat.id, get_object_info(msg.forward_from_chat, msg.chat.id))
                end
            end
        end
        return msg
    end
end

return {
    description = "INFO",
    patterns =
    {
        "^[#!/]([Ii][Dd])$",
        "^[#!/]([Ii][Dd]) ([^%s]+)$",
        "^[#!/]([Uu][Ss][Ee][Rr][Nn][Aa][Mm][Ee])$",
        "^[#!/]([Uu][Ss][Ee][Rr][Nn][Aa][Mm][Ee]) ([^%s]+)$",
        "^[#!/]([Gg][Rr][Oo][Uu][Pp][Ll][Ii][Nn][Kk]) (%-%d+)$",
        "^[#!/]([Ii][Ss][Hh][Ee][Rr][Ee])$",
        "^[#!/]([Ii][Ss][Hh][Ee][Rr][Ee]) ([^%s]+)$",
        "^[#!/]([Gg][Ee][Tt][Rr][Aa][Nn][Kk])$",
        "^[#!/]([Gg][Ee][Tt][Rr][Aa][Nn][Kk]) ([^%s]+)$",
        "^[#!/]([Ww][Hh][Oo][Aa][Mm][Ii])$",
        "^[#!/]([Ii][Nn][Ff][Oo])$",
        "^[#!/]([Ii][Nn][Ff][Oo]) ([^%s]+)$",
        "^[#!/]([Tt][Ee][Xx][Tt][Uu][Aa][Ll][Ii][Nn][Ff][Oo])$",
        "^[#!/]([Tt][Ee][Xx][Tt][Uu][Aa][Ll][Ii][Nn][Ff][Oo]) ([^%s]+)$",
        -- "^[#!/]([Ww][Hh][Oo])$",
        -- who
        -- "^[#!/]([Mm][Ee][Mm][Bb][Ee][Rr][Ss])$",
    },
    run = run,
    pre_process = pre_process,
    min_rank = 0,
    syntax =
    {
        "USER",
        "#id",
        "#username",
        "#getrank [<id>|<username>|<reply>|from]",
        "#whoami",
        "#[textual]info",
        "#ishere <id>|<username>|<reply>|from",
        "MOD",
        "#id <username>|<reply>|from",
        "#username <id>|<reply>|from",
        "#[textual]info <id>|<username>|<reply>|from",
        -- "(#who|#members)",
        "ADMIN",
        "#grouplink <group_id>",
    },
}