defmodule Twitter.MuginuChannel do
    use Phoenix.Channel

    def join("lobby", _payload, socket) do
      {:ok, socket}
    end

    def handle_in("registeration", payload, socket) do
        user_ID = payload["username"]
        pass = payload["password"]
        :ets.insert_new(:usersinfo, {user_ID, pass})
        {:noreply, socket}
    end

    def handle_in("login", payload, socket) do
        user_ID = payload["username"]
        password = payload["password"]
        login_pass = if :ets.lookup(:usersinfo, user_ID) != [] do
            elem(List.first(:ets.lookup(:usersinfo, user_ID)), 1)
        else
            ""
        end

        if login_pass == password do
            :ets.insert(:mapping_of_sockets, {user_ID, socket})
            push socket, "Login", %{login_status: "Successfully Logged in" , user_name: user_ID }
        else
            push socket, "Login", %{login_status: "Login Failed" , user_name: user_ID}
        end
        {:noreply, socket}
    end

    def handle_in("update_socket", payload, socket) do
        userID = Map.get(payload, "username")
        :ets.insert(:mapping_of_sockets, {userID, socket})
        {:noreply, socket}
    end

    def handle_in("subscribeTo", payload, socket) do
        userID = Map.get(payload, "username2")
        selfId = Map.get(payload, "selfId")
        :ets.insert(:mapping_of_sockets, {selfId, socket})

        mapSet =
          if :ets.lookup(:followersTable, userID) == [] do
              MapSet.new
          else
              [{_, set}] = :ets.lookup(:followersTable, userID)
              set
          end

          mapSet = MapSet.put(mapSet, selfId)

          :ets.insert(:followersTable, {userID, mapSet})

          mapSet2 =
          if :ets.lookup(:followsTable, selfId) == [] do
            MapSet.new
          else
           [{_, set}] = :ets.lookup(:followsTable, selfId)
           set
          end

          mapSet2 = MapSet.put(mapSet2, userID)

          :ets.insert(:followsTable, {selfId, mapSet2})

        push socket, "AddToFollowsList", %{follows: mapSet2}
        {:noreply, socket}
      end

      def handle_in("reTweet", payload, socket) do
        IO.inspect "RETWEETING!"
        nextID = :ets.info(:tweetsDataBase)[:size]

        username = Map.get(payload, "username")
        content = Map.get(payload, "tweet")
        org_user = Map.get(payload, "org")

        :ets.insert(:mapping_of_sockets, {username, socket})
      #  {hashtags, mentions} = extract_Mentions_Hashtags(content)
        split_words=String.split(content," ")
        hashtags=find_HashTags(split_words,[])
        mentions=findMentions(split_words,[])

        :ets.insert(:tweetsDataBase, {nextID, username, content, true, org_user})

        mentionsMapupdate(mentions, nextID)
        hashTagMapupdate(hashtags, nextID)

        #broadcast
        followers =
        if List.first(:ets.lookup(:followersTable, username)) == nil do
            []
        else
            MapSet.to_list(elem(List.first(:ets.lookup(:followersTable, username)), 1))
        end

        payload2 = %{tweeter: username, tweetText: content, isRetweet: true, org: org_user}
        # IO.inspect payload2
        sendingFollowers(followers, nextID, username, payload2)
        sendingFollowers(mentions, nextID, username, payload2)
        {:noreply, socket}
    end

    # def parseContent(content) do
    #     map = Regex.named_captures(~r/(?<tweeter>[a-z|A-Z|\d]+) tweeted: (?<text>[a-z|A-Z| |@|#|\d]*)/, content)
    #     {Map.get(map,"text"), Map.get(map,"tweeter")}
    # end

      def handle_in("getMyMentions", payload, socket) do
        IO.inspect "RETWEETING!"
        username = Map.get(payload, "username")
        mentions =
        if :ets.lookup(:mentionsMapping, username) == [] do
          MapSet.new
        else
          [{_, set}] = :ets.lookup(:mentionsMapping, username)
          set
        end
        mentionedTweets = get_Mentions(MapSet.to_list(mentions), [])
        push socket, "ReceiveMentions", %{tweets: mentionedTweets}
        {:noreply, socket}
    end

    def handle_in("tweetsWithHashtag", payload, socket) do
        hashtag = Map.get(payload, "hashtag")

        tweets =
        if :ets.lookup(:hashtagMapping, hashtag) == [] do
          MapSet.new
        else
          [{_, set}] = :ets.lookup(:hashtagMapping, hashtag)
          set
        end

        hashtagTweets = getHashtags(MapSet.to_list(tweets), [])
        push socket, "ReceiveHashtags", %{tweets: hashtagTweets}
        {:noreply, socket}
    end

      def handle_in("tweet", payload, socket) do
        IO.inspect "RECEIVED A TWEET!"
        username = Map.get(payload, "username")
        content = Map.get(payload, "tweetText")
        :ets.insert(:mapping_of_sockets, {username, socket})
        #{hashtags, mentions} = extract_Mentions_Hashtags(content)
        split_words=String.split(content," ")
        hashtags=find_HashTags(split_words,[])
        mentions=findMentions(split_words,[])
        nextID = :ets.info(:tweetsDataBase)[:size]

        :ets.insert(:tweetsDataBase, {nextID, username, content, false, nil})

        mentionsMapupdate(mentions, nextID)
        hashTagMapupdate(hashtags, nextID)

        #broadcast
        followers =
        if List.first(:ets.lookup(:followersTable, username)) == nil do
            []
        else
            MapSet.to_list(elem(List.first(:ets.lookup(:followersTable, username)), 1))
        end
        payload2 = %{tweeter: username, tweetText: content, isRetweet: false, org: nil}
        sendingFollowers(followers, nextID, username, payload2)
        sendingFollowers(mentions, nextID, username, payload2)

        {:noreply, socket}
    end

    def handle_in("queryTweets", payload, socket) do
        username = Map.get(payload, "username")

        mapSet =
        if :ets.lookup(:followsTable,username) == [] do
          MapSet.new
        else
          [{_, set}] = :ets.lookup(:followsTable,username)
          set
        end
       # IO.inspect mapSet

        result =
        for f_user <- MapSet.to_list(mapSet) do
          list_of_tweets = List.flatten(:ets.match(:tweetsDataBase, {:_, f_user, :"$1", :_, :_}))
          Enum.map(list_of_tweets, fn tweetContent -> %{tweeter: f_user, tweet: tweetContent} end)
      end

        push socket, "ReceiveQueryResults", %{tweets: List.flatten(result)}
        {:noreply, socket}
    end

    def getHashtags([index | rest], hashtagTweets) do
        [{index, username, content, isRetweet, org_tweeter}] = :ets.lookup(:tweetsDataBase, index)
        hashtagTweets = List.insert_at(hashtagTweets, 0, %{tweetID: index, tweeter: username, tweet: content, isRetweet: isRetweet, org: org_tweeter})
        getHashtags(rest, hashtagTweets)
    end

    def getHashtags([], hashtagTweets) do
        hashtagTweets
    end

    def get_Mentions([index | rest], mentionedTweets) do
        [{index, username, content, isRetweet, org_tweeter}] = :ets.lookup(:tweetsDataBase, index)
        mentionedTweets = List.insert_at(mentionedTweets, 0, %{tweetID: index, tweeter: username, tweet: content, isRetweet: isRetweet, org: org_tweeter})
        get_Mentions(rest, mentionedTweets)
    end

    def get_Mentions([], mentionedTweets) do
        mentionedTweets
    end

    def extract_Mentions_Hashtags(content) do
        split_words=String.split(content," ")
        hashtags=find_HashTags(split_words,[])
        mentions=findMentions(split_words,[])
        {hashtags, mentions}
    end

    def find_HashTags([head|tail],hashList) do
        if(String.first(head)=="#") do
          [_, elem] = String.split(head, "#")
          find_HashTags(tail,List.insert_at(hashList, 0, head))
        else
          find_HashTags(tail,hashList)
        end

      end

      def find_HashTags([],hashList) do
        hashList
      end

      def findMentions([head|tail],mentionList) do
        if(String.first(head)=="@") do
          [_, elem] = String.split(head, "@")
          findMentions(tail,List.insert_at(mentionList, 0, elem))

        else
          findMentions(tail,mentionList)
        end

      end

      def findMentions([],mentionList) do
        mentionList
      end

      def mentionsMapupdate([mention | mentions], index) do
        elems =
        if :ets.lookup(:mentionsMapping, mention) == [] do
            element = MapSet.new
            MapSet.put(element, index)
        else
            [{_,element}] = :ets.lookup(:mentionsMapping, mention)
          MapSet.put(element, index)
        end

        :ets.insert(:mentionsMapping, {mention, elems})
        mentionsMapupdate(mentions, index)
    end

    def mentionsMapupdate([], _) do
    end

    def hashTagMapupdate([hashtag | hashtags], index) do
        #IO.inspect hashtag
        elems =
        if :ets.lookup(:hashtagMapping, hashtag) == [] do
            element = MapSet.new
            MapSet.put(element, index)
        else
            [{_,element}] = :ets.lookup(:hashtagMapping, hashtag)
            MapSet.put(element, index)
        end

        :ets.insert(:hashtagMapping, {hashtag, elems})
        hashTagMapupdate(hashtags, index)
    end

    def hashTagMapupdate([], _) do
    end

    def sendingFollowers([first | followers], index, username, payload) do
        push elem(List.first(:ets.lookup(:mapping_of_sockets, first)), 1),  "ReceiveTweet", payload
        sendingFollowers(followers, index, username, payload)
    end

    def sendingFollowers([], _, _, _) do
    end

    def fetchRelevantTweets(mapSet) do
        result =
        for f_user <- MapSet.to_list(mapSet) do
          list_of_tweets = List.flatten(:ets.match(:tweetsDataBase, {:_, f_user, :"$1", :_, :_}))
          Enum.map(list_of_tweets, fn tweetContent -> %{tweeter: f_user, tweet: tweetContent} end)
      end
      List.flatten(result)
    end

  end
