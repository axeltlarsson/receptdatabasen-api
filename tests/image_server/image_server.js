import { image_service } from '../common'
import should from 'should'
import * as fs from 'fs'
import * as path from 'path'

describe('image server', function () {
  let uploadedFileName = ''

  it('uploads an image file', function(done) {

    let testImage = readFile('../data/test.jpg');

    function readFile(relPath) {
      return fs.readFileSync(path.join(__dirname, relPath))
    }

    image_service()
      .post('/upload')
      .set('Content-type', 'image/jpg')
      .send(testImage)
      .expect(res => {
        res.body.should.have.keys('image')
        res.body.image.should.have.keys('url')
        // /images/8341b94cc06107b1641bb323756fcaa6.jpg 
        // => 8341b94cc06107b1641bb323756fcaa6.jpg 
        uploadedFileName = res.body.image.url.split("/")[2]
      })
      .expect(200, done)
  })


  it('serves resized uploaded image', function (done) {
    image_service()
      .get('/sig/100/' + uploadedFileName)
      .responseType("blob")
      .expect('Content-Type', "image/jpeg")
      .then(res => {
        // test.jpg resized to width 100 should have this length
        res.body.length.should.equal(4473)
        done()
      })

  })

})
