import unittest
import json
import sys
sys.path.append("..")
from api import OoyalaAPI

class TestOoyalaAPI(unittest.TestCase):
    def setUp(self):
        self.api = OoyalaAPI('',
                             '')

    def test_get(self):
        # Get all assets
        res = self.api.get('assets')
        self.assertIsNotNone(res, 'Response should not be None')
        self.assertTrue(len(res)>0, 'Response string should be non-empty')

    def test_post(self):
        # Create a new channel
        res = self.api.post('assets', 
                            {"name": "My new channel","asset_type": "channel"})
        self.assertTrue(res['embed_code'], 'embed_code should be present')
    
        # Delete create asset
        path = 'assets/' + res['embed_code']
        res = self.api.delete(path)
        self.assertTrue(res, 'Response should be True')
    
    def test_put(self):
        # Create a new channel
        res = self.api.post('assets',
                            {"name": "My new channel","asset_type": "channel"})
        channel_id = res['embed_code'] # Get channel id
    
        # Create a new video
        res = self.api.post('assets', 
                            {"name": "My asset on YouTube","asset_type": "youtube","youtube_id": "yyNqLNX02CU"})
        video_id = res['embed_code'] # Get channel id
    
        #Set a new line-up through a PUT request
        path  = 'assets/%s/lineup' % channel_id
        res = self.api.put(path, [video_id])
    
        # Remove channel and video assets
        self.assertTrue(self.api.delete('assets/%s' % channel_id))
        self.assertTrue(self.api.delete('assets/%s' % video_id))
    
    def test_patch(self):
        #create a new video
        res = self.api.post('assets',
                            {"name": "My asset on YouTube","asset_type": "youtube","youtube_id": "yyNqLNX02CU"})
    
        video_id = res['embed_code'] # Get channel id
    
        #change the video's name 
        res = self.api.patch('assets/%s' % video_id,
                             {"name":"new asset name"})
    
        # Remove channel and video assets
        self.assertTrue(self.api.delete('assets/%s' % video_id))

    def runTest(self):
        self.test_get()
        self.test_post()
        self.test_patch()
        self.test_put()

if __name__ == "__main__":
    test = TestOoyalaAPI()
    test.setUp()
    test.runTest()